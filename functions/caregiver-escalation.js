/* eslint-disable require-jsdoc */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const TIME_ZONE = "America/Sao_Paulo";

function localClock(date) {
  const parts = Object.fromEntries(
      new Intl.DateTimeFormat("en-CA", {
        timeZone: TIME_ZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
        weekday: "short",
      })
          .formatToParts(date)
          .filter((part) => part.type !== "literal")
          .map((part) => [part.type, part.value]),
  );
  const weekdays = {Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7};
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    weekday: weekdays[parts.weekday],
    dateKey: `${parts.year}${parts.month}${parts.day}`,
  };
}

function dateKey(value) {
  const parsed = value?.toDate ? value.toDate() : new Date(value);
  if (Number.isNaN(parsed?.getTime())) return null;
  return localClock(parsed).dateKey;
}

function activeToday(reminder, clock) {
  const recurrence = reminder.recorrencia || "diario";
  if (recurrence === "unico" || reminder.lembreteUnico === true) {
    return dateKey(reminder.dataInicio || reminder.criadoEm) === clock.dateKey;
  }
  if (recurrence === "semanal" || reminder.recorrenciaSemanal === true) {
    return Array.isArray(reminder.diasSemana) &&
      reminder.diasSemana.includes(clock.weekday);
  }
  if (recurrence === "mensal" || reminder.recorrenciaMensal === true) {
    return Number(reminder.diaMes) === clock.day;
  }
  if (recurrence === "quinzenal") {
    const start = reminder.dataInicio?.toDate ?
      reminder.dataInicio.toDate() :
      new Date(reminder.dataInicio || reminder.criadoEm);
    if (Number.isNaN(start.getTime())) return false;
    const todayUtc = Date.UTC(clock.year, clock.month - 1, clock.day);
    const startClock = localClock(start);
    const startUtc = Date.UTC(
        startClock.year,
        startClock.month - 1,
        startClock.day,
    );
    const days = Math.floor((todayUtc - startUtc) / 86400000);
    return days >= 0 && days % 15 === 0;
  }
  return true;
}

function linkedCaregivers(profile) {
  const ids = Array.isArray(profile.caregiverIds) ?
    profile.caregiverIds.filter((id) => typeof id === "string" && id) :
    [];
  if (typeof profile.supervisorId === "string" && profile.supervisorId) {
    ids.push(profile.supervisorId);
  }
  const routing =
    profile.caregiverRouting && typeof profile.caregiverRouting === "object" ?
      profile.caregiverRouting :
      {};
  return [...new Set(ids)]
      .map((id, index) => ({
        id,
        priority: Number(routing[id]?.priority) || index + 1,
        availableStart: routing[id]?.availableStart || "00:00",
        availableEnd: routing[id]?.availableEnd || "23:59",
        alertTypes: Array.isArray(routing[id]?.alertTypes) ?
        routing[id].alertTypes :
        ["missed_reminder"],
      }))
      .filter((caregiver) => caregiver.alertTypes.includes("missed_reminder"))
      .sort((a, b) => a.priority - b.priority)
      .slice(0, 8);
}

function isAvailable(caregiver, currentMinutes) {
  const toMinutes = (value) => {
    const [hour, minute] = String(value).split(":").map(Number);
    return hour * 60 + minute;
  };
  const start = toMinutes(caregiver.availableStart);
  const end = toMinutes(caregiver.availableEnd);
  return start <= end ?
    currentMinutes >= start && currentMinutes <= end :
    currentMinutes >= start || currentMinutes <= end;
}

exports.escalateMissedReminders = onSchedule(
    {
      schedule: "every 5 minutes",
      timeZone: TIME_ZONE,
      region: "southamerica-east1",
      maxInstances: 1,
    },
    async () => {
      const db = admin.firestore();
      const now = new Date();
      const clock = localClock(now);
      const currentMinutes = clock.hour * 60 + clock.minute;
      const reminders = await db
          .collection("lembretes")
          .where("avisarCuidador", "==", true)
          .limit(500)
          .get();
      const profileCache = new Map();
      const tokenCache = new Map();

      for (const document of reminders.docs) {
        const reminder = document.data() || {};
        if (reminder.arquivado === true) continue;
        if (!reminder.idosoId || !activeToday(reminder, clock)) continue;
        const hour = Number(
            reminder.originalHorarioHour ?? reminder.horarioHour,
        );
        const minute = Number(
            reminder.originalHorarioMinute ?? reminder.horarioMinute,
        );
        if (!Number.isInteger(hour) || !Number.isInteger(minute)) continue;
        const scheduledMinutes = hour * 60 + minute;
        const lateMinutes = currentMinutes - scheduledMinutes;
        const tolerance = Math.max(1, Number(reminder.toleranciaMinutos) || 30);
        if (lateMinutes < tolerance || lateMinutes > 24 * 60) continue;

        const occurrenceKey = `${document.id}_${clock.dateKey}_` +
        `${String(hour).padStart(2, "0")}${String(minute).padStart(2, "0")}`;
        const alertId = `${occurrenceKey}_escalation`;
        const alertRef = db.collection("alertas").doc(alertId);
        const completion = await db
            .collection("lembrete_eventos")
            .doc(`confirm_${occurrenceKey}`)
            .get();
        if (completion.exists) {
          const existingAlert = await alertRef.get();
          if (existingAlert.exists &&
              existingAlert.data()?.status !== "resolved") {
            const resolvedAt = admin.firestore.Timestamp.now();
            await alertRef.update({
              status: "resolved",
              resolvidoEm: resolvedAt,
              resolucao: "Lembrete confirmado.",
              updatedAt: resolvedAt,
            });
          }
          continue;
        }

        let profile = profileCache.get(reminder.idosoId);
        if (!profile) {
          const profileSnap = await db
              .collection("idoso_perfil")
              .doc(reminder.idosoId)
              .get();
          profile = profileSnap.data() || {};
          profileCache.set(reminder.idosoId, profile);
        }
        const caregivers = linkedCaregivers(profile).filter((caregiver) =>
          isAvailable(caregiver, currentMinutes),
        );
        if (caregivers.length === 0) continue;
        const interval = Math.max(
            5,
            Number(reminder.intervaloRepeticaoMinutos) || 5,
        );
        const level = Math.min(
            caregivers.length - 1,
            Math.floor((lateMinutes - tolerance) / interval),
        );
        const caregiver = caregivers[level];
        const alertMessage = `${reminder.titulo || "Atividade"} está ` +
          `${lateMinutes} min atrasado.`;
        const shouldNotify = await db.runTransaction(async (transaction) => {
          const existing = await transaction.get(alertRef);
          const existingData = existing.data() || {};
          if (existingData.status === "acknowledged" ||
              existingData.status === "resolved") {
            return false;
          }
          if (existing.exists &&
              Number(existingData.nivelEscalonamento) >= level) {
            return false;
          }
          const nowTimestamp = admin.firestore.Timestamp.now();
          const alertData = {
            id: alertId,
            idosoId: reminder.idosoId,
            tipo: "missed_reminder",
            titulo: "Lembrete sem resposta",
            mensagem: alertMessage,
            severidade: reminder.prioridade === "critica" ? 3 : 2,
            status: "open",
            origemId: document.id,
            nivelEscalonamento: level,
            notificadoParaId: caregiver.id,
            notificadoEm: nowTimestamp,
            updatedAt: nowTimestamp,
          };
          if (existing.exists) {
            transaction.update(alertRef, alertData);
          } else {
            transaction.create(alertRef, {
              ...alertData,
              createdAt: nowTimestamp,
            });
          }
          return true;
        });
        if (!shouldNotify) continue;

        let token = tokenCache.get(caregiver.id);
        if (token === undefined) {
          const tokenSnap = await db
              .collection("fcm_tokens")
              .doc(`supervisor_${caregiver.id}`)
              .get();
          token = tokenSnap.data()?.token || null;
          tokenCache.set(caregiver.id, token);
        }
        if (!token) {
          await alertRef.update({deliveryStatus: "token_missing"});
          continue;
        }
        try {
          await admin.messaging().send({
            token,
            notification: {
              title: "Lembrete sem resposta",
              body: alertMessage,
            },
            data: {
              type: "missed_reminder",
              elderlyId: String(reminder.idosoId),
              reminderId: document.id,
              alertId,
            },
            android: {priority: "high", ttl: 24 * 60 * 60 * 1000},
            apns: {
              headers: {
                "apns-priority": "10",
                "apns-expiration": String(
                    Math.floor(Date.now() / 1000) + 86400,
                ),
              },
              payload: {aps: {sound: "default", badge: 1}},
            },
          });
          await alertRef.update({deliveryStatus: "sent"});
        } catch (error) {
          console.error("escalateMissedReminders send error", error);
          await alertRef.update({deliveryStatus: "failed"});
        }
      }
    },
);
