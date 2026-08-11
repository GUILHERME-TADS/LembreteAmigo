/* eslint-disable require-jsdoc */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const CALL_OPTIONS = {cors: true, enforceAppCheck: true};

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuario nao autenticado.");
  }
  return request.auth.uid;
}

function validateId(value, name, maxLength = 128) {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > maxLength ||
    !/^[a-zA-Z0-9_-]+$/.test(value)
  ) {
    throw new HttpsError("invalid-argument", `${name} invalido.`);
  }
  return value;
}

function validateOccurrenceKey(value, reminderId) {
  const key = validateId(value, "occurrenceKey", 160);
  const prefix = `${reminderId}_`;
  const suffix = key.startsWith(prefix) ? key.slice(prefix.length) : "";
  if (!/^[0-9]{8}_[0-9]{4}$/.test(suffix)) {
    throw new HttpsError(
        "invalid-argument",
        "A ocorrencia informada nao corresponde ao lembrete.",
    );
  }
  return key;
}

function validateOccurrenceForReminder(occurrenceKey, reminder) {
  const match = occurrenceKey.match(/_([0-9]{8})_([0-9]{2})([0-9]{2})$/);
  if (!match) {
    throw new HttpsError("invalid-argument", "Ocorrencia invalida.");
  }
  const now = new Date();
  const localParts = Object.fromEntries(
      new Intl.DateTimeFormat("en-CA", {
        timeZone: "America/Sao_Paulo",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
      })
          .formatToParts(now)
          .filter((part) => part.type !== "literal")
          .map((part) => [part.type, part.value]),
  );
  const today = `${localParts.year}${localParts.month}${localParts.day}`;
  let expectedMinutes =
    Number(reminder.originalHorarioHour ?? reminder.horarioHour) * 60 +
    Number(reminder.originalHorarioMinute ?? reminder.horarioMinute);
  if (reminder.recorrenciaIntervalo || reminder.recorrencia === "intervalo") {
    const interval = Math.max(1, Number(reminder.intervaloHoras) || 4) * 60;
    const currentMinutes = Number(localParts.hour) * 60 +
      Number(localParts.minute);
    if (currentMinutes >= expectedMinutes) {
      expectedMinutes +=
        Math.floor((currentMinutes - expectedMinutes) / interval) * interval;
    }
  }
  const expectedHour = String(Math.floor(expectedMinutes / 60) % 24)
      .padStart(2, "0");
  const expectedMinute = String(expectedMinutes % 60).padStart(2, "0");
  if (match[1] !== today || match[2] !== expectedHour ||
      match[3] !== expectedMinute) {
    throw new HttpsError(
        "failed-precondition",
        "Esta confirmacao nao corresponde ao horario atual do lembrete.",
    );
  }
}

function caregiverIds(profile) {
  const values = Array.isArray(profile?.caregiverIds) ?
    profile.caregiverIds.filter((id) => typeof id === "string" && id) :
    [];
  if (typeof profile?.supervisorId === "string" && profile.supervisorId) {
    values.push(profile.supervisorId);
  }
  return [...new Set(values)].slice(0, 8);
}

function caregiverCanManage(profile, uid) {
  if (!caregiverIds(profile).includes(uid)) return false;
  if (profile?.supervisorId === uid) return true;
  const roles = profile?.caregiverRoles;
  const role = roles && typeof roles === "object" && !Array.isArray(roles) ?
    roles[uid] :
    null;
  return ["primary", "backup", "family"].includes(role);
}

async function assertReminderManager(transaction, reminder, uid) {
  const elderlyId = validateId(reminder.idosoId, "reminder.idosoId");
  if (uid === elderlyId) return;
  const profileRef = admin
      .firestore()
      .collection("idoso_perfil")
      .doc(elderlyId);
  const profileSnapshot = await transaction.get(profileRef);
  const profile = profileSnapshot.data() || {};
  if (
    !profileSnapshot.exists ||
    profile.status !== "active" ||
    !caregiverCanManage(profile, uid)
  ) {
    throw new HttpsError(
        "permission-denied",
        "Voce nao pode confirmar este lembrete.",
    );
  }
}

async function checkRateLimit(uid, functionName, maxCalls) {
  const db = admin.firestore();
  const ref = db.collection("_rate_limits").doc(`${functionName}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    if (!snapshot.exists || now - Number(data.windowStart || 0) > 60000) {
      transaction.set(ref, {uid, functionName, windowStart: now, count: 1});
      return;
    }
    if (Number(data.count || 0) >= maxCalls) {
      throw new HttpsError(
          "resource-exhausted",
          "Muitas tentativas. Aguarde um minuto.",
      );
    }
    transaction.update(ref, {count: admin.firestore.FieldValue.increment(1)});
  });
}

function validateConfirmationMethod(value) {
  if (!["botao", "voz", "foto", "cuidador"].includes(value)) {
    throw new HttpsError(
        "invalid-argument",
        "Metodo de confirmacao invalido.",
    );
  }
  return value;
}

function validatePhotoPath(value) {
  if (value === null || value === undefined) return null;
  if (
    typeof value !== "string" ||
    value.length > 2048 ||
    !value.startsWith("https://")
  ) {
    throw new HttpsError(
        "invalid-argument",
        "A foto de confirmacao deve usar uma URL segura.",
    );
  }
  return value;
}

function assertMethodAllowed(reminder, method, uid, photoPath) {
  const mode = reminder.modoConfirmacao ||
    (reminder.categoria === "medicacao" ? "foto" : "simples");
  if (mode === "foto" && (method !== "foto" || !photoPath)) {
    throw new HttpsError(
        "failed-precondition",
        "Este lembrete exige confirmacao com foto.",
    );
  }
  if (mode === "cuidador" && method !== "cuidador") {
    throw new HttpsError(
        "failed-precondition",
        "Este lembrete precisa ser confirmado por um cuidador.",
    );
  }
  if (method === "cuidador" && uid === reminder.idosoId) {
    throw new HttpsError(
        "permission-denied",
        "A confirmacao do cuidador nao pode ser feita pelo idoso.",
    );
  }
  if (mode === "voz_ou_botao" && !["voz", "botao"].includes(method)) {
    throw new HttpsError(
        "failed-precondition",
        "Use voz ou botao para confirmar este lembrete.",
    );
  }
}

const confirmReminderOccurrence = onCall(CALL_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "confirmReminderOccurrence", 20);
  const reminderId = validateId(request.data?.reminderId, "reminderId");
  const occurrenceKey = validateOccurrenceKey(
      request.data?.occurrenceKey,
      reminderId,
  );
  const method = validateConfirmationMethod(request.data?.method);
  const photoPath = validatePhotoPath(request.data?.photoPath);
  const db = admin.firestore();
  const reminderRef = db.collection("lembretes").doc(reminderId);
  const eventId = `confirm_${occurrenceKey}`;
  const eventRef = db.collection("lembrete_eventos").doc(eventId);

  try {
    return await db.runTransaction(async (transaction) => {
      const reminderSnapshot = await transaction.get(reminderRef);
      if (!reminderSnapshot.exists) {
        throw new HttpsError("not-found", "Lembrete nao encontrado.");
      }
      const reminder = reminderSnapshot.data() || {};
      if (reminder.arquivado === true) {
        throw new HttpsError(
            "failed-precondition",
            "Lembrete arquivado nao pode ser confirmado.",
        );
      }
      validateOccurrenceForReminder(occurrenceKey, reminder);
      await assertReminderManager(transaction, reminder, uid);
      const existingEvent = await transaction.get(eventRef);
      if (existingEvent.exists) {
        const existing = existingEvent.data() || {};
        return {
          success: true,
          duplicate: true,
          eventId,
          status: existing.status || "concluido",
          registeredAt: existing.registradoEm || new Date().toISOString(),
          remainingStock: existing.estoqueRestante ?? null,
        };
      }

      assertMethodAllowed(reminder, method, uid, photoPath);
      const previousStock = Number.isInteger(reminder.medicamentoEstoque) ?
        reminder.medicamentoEstoque :
        null;
      const unitsPerDose =
        typeof reminder.medicamentoUnidadesPorDose === "number" &&
        Number.isFinite(reminder.medicamentoUnidadesPorDose) ?
          reminder.medicamentoUnidadesPorDose :
          null;
      const consumedUnits = previousStock !== null && unitsPerDose !== null ?
        Math.ceil(unitsPerDose) :
        null;
      const remainingStock = consumedUnits === null ?
        previousStock :
        Math.max(0, previousStock - consumedUnits);
      const status = method === "foto" ?
        "concluido_com_foto" :
        method === "cuidador" ?
          "confirmado_pelo_cuidador" :
          "concluido";
      const registeredAt = new Date().toISOString();
      const stockMovementRef = consumedUnits === null ?
        null :
        db.collection("estoque_movimentos").doc(`consume_${occurrenceKey}`);
      const minimumStock = Number.isInteger(
          reminder.medicamentoEstoqueMinimo,
      ) ? reminder.medicamentoEstoqueMinimo : null;
      const lowStockRef = remainingStock !== null &&
        minimumStock !== null &&
        remainingStock <= minimumStock ?
        db.collection("alertas").doc(`low_stock_${reminderId}`) :
        null;

      const reminderPatch = {
        status,
        concluido: true,
        concluidoComFoto: status === "concluido_com_foto",
      };
      if (remainingStock !== null) {
        reminderPatch.medicamentoEstoque = remainingStock;
      }
      transaction.update(reminderRef, reminderPatch);

      const event = {
        id: eventId,
        lembreteId: reminderId,
        titulo: String(reminder.titulo || "Lembrete").slice(0, 200),
        categoria: String(reminder.categoria || "personalizado"),
        status,
        registradoEm: registeredAt,
        idosoId: reminder.idosoId,
        observacao: "Confirmacao registrada de forma transacional.",
        ocorrenciaChave: occurrenceKey,
        metodoConfirmacao: method,
        atorPapel: uid === reminder.idosoId ? "elderly" : "supervisor",
      };
      if (photoPath) event.fotoConfirmacaoPath = photoPath;
      if (previousStock !== null) event.estoqueAnterior = previousStock;
      if (consumedUnits !== null) {
        event.unidadesConsumidas = consumedUnits;
        event.estoqueRestante = remainingStock;
      }
      transaction.create(eventRef, event);
      if (stockMovementRef !== null) {
        transaction.create(stockMovementRef, {
          id: `consume_${occurrenceKey}`,
          idosoId: reminder.idosoId,
          lembreteId: reminderId,
          tipo: "consumo",
          quantidade: consumedUnits,
          estoqueAnterior: previousStock,
          estoquePosterior: remainingStock,
          ocorrenciaChave: occurrenceKey,
          createdAt: admin.firestore.Timestamp.now(),
          createdBy: uid,
        });
      }
      if (lowStockRef !== null) {
        const nowTimestamp = admin.firestore.Timestamp.now();
        transaction.set(lowStockRef, {
          id: `low_stock_${reminderId}`,
          idosoId: reminder.idosoId,
          tipo: "low_stock",
          titulo: "Estoque baixo",
          mensagem:
            `${String(reminder.titulo || "Medicamento").slice(0, 120)} ` +
            `tem ${remainingStock} unidade(s) restante(s).`,
          severidade: remainingStock === 0 ? 3 : 2,
          status: "open",
          origemId: reminderId,
          createdAt: nowTimestamp,
          updatedAt: nowTimestamp,
        }, {merge: true});
      }
      return {
        success: true,
        duplicate: false,
        eventId,
        status,
        registeredAt,
        remainingStock,
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("confirmReminderOccurrence error:", error);
    throw new HttpsError("internal", "Nao foi possivel confirmar o lembrete.");
  }
});

const undoReminderConfirmation = onCall(CALL_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "undoReminderConfirmation", 10);
  const reminderId = validateId(request.data?.reminderId, "reminderId");
  const occurrenceKey = validateOccurrenceKey(
      request.data?.occurrenceKey,
      reminderId,
  );
  const db = admin.firestore();
  const reminderRef = db.collection("lembretes").doc(reminderId);
  const completionEventId = `confirm_${occurrenceKey}`;
  const completionRef = db
      .collection("lembrete_eventos")
      .doc(completionEventId);
  const correctionEventId = `undo_${occurrenceKey}`;
  const correctionRef = db
      .collection("lembrete_eventos")
      .doc(correctionEventId);

  try {
    return await db.runTransaction(async (transaction) => {
      const reminderSnapshot = await transaction.get(reminderRef);
      if (!reminderSnapshot.exists) {
        throw new HttpsError("not-found", "Lembrete nao encontrado.");
      }
      const reminder = reminderSnapshot.data() || {};
      if (reminder.arquivado === true) {
        throw new HttpsError(
            "failed-precondition",
            "Lembrete arquivado nao pode ser alterado.",
        );
      }
      validateOccurrenceForReminder(occurrenceKey, reminder);
      await assertReminderManager(transaction, reminder, uid);
      const completionSnapshot = await transaction.get(completionRef);
      const correctionSnapshot = await transaction.get(correctionRef);
      if (!completionSnapshot.exists) {
        throw new HttpsError(
            "failed-precondition",
            "Nao existe confirmacao para desfazer.",
        );
      }
      if (correctionSnapshot.exists) {
        const correction = correctionSnapshot.data() || {};
        return {
          success: true,
          duplicate: true,
          eventId: correctionEventId,
          registeredAt: correction.registradoEm || new Date().toISOString(),
          restoredStock: correction.estoqueRestaurado ?? null,
        };
      }

      const completion = completionSnapshot.data() || {};
      const completionTime = Date.parse(completion.registradoEm || "");
      if (
        !Number.isFinite(completionTime) ||
        Date.now() - completionTime > 30000
      ) {
        throw new HttpsError(
            "failed-precondition",
            "O tempo de 30 segundos para desfazer terminou.",
        );
      }

      const restoredStock = Number.isInteger(completion.estoqueAnterior) ?
        completion.estoqueAnterior :
        null;
      const stockUndoRef = restoredStock === null ?
        null :
        db.collection("estoque_movimentos").doc(`undo_${occurrenceKey}`);
      const lowStockAlertRef = restoredStock === null ?
        null :
        db.collection("alertas").doc(`low_stock_${reminderId}`);
      const lowStockAlertSnapshot = lowStockAlertRef === null ?
        null : await transaction.get(lowStockAlertRef);
      const reminderPatch = {
        status: "pendente",
        concluido: false,
        concluidoComFoto: false,
      };
      if (restoredStock !== null) {
        reminderPatch.medicamentoEstoque = restoredStock;
      }
      transaction.update(reminderRef, reminderPatch);

      const registeredAt = new Date().toISOString();
      const correction = {
        id: correctionEventId,
        lembreteId: reminderId,
        titulo: String(reminder.titulo || "Lembrete").slice(0, 200),
        categoria: String(reminder.categoria || "personalizado"),
        status: "pendente",
        registradoEm: registeredAt,
        idosoId: reminder.idosoId,
        observacao: "Confirmacao desfeita na janela de seguranca.",
        ocorrenciaChave: occurrenceKey,
        metodoConfirmacao: "sistema",
        corrigeEventoId: completionEventId,
        atorPapel: uid === reminder.idosoId ? "elderly" : "supervisor",
      };
      if (restoredStock !== null) {
        correction.estoqueRestaurado = restoredStock;
      }
      transaction.create(correctionRef, correction);
      if (stockUndoRef !== null) {
        transaction.create(stockUndoRef, {
          id: `undo_${occurrenceKey}`,
          idosoId: reminder.idosoId,
          lembreteId: reminderId,
          tipo: "estorno",
          quantidade: Number(completion.unidadesConsumidas) || 0,
          estoqueAnterior: Number(completion.estoqueRestante) || 0,
          estoquePosterior: restoredStock,
          ocorrenciaChave: occurrenceKey,
          createdAt: admin.firestore.Timestamp.now(),
          createdBy: uid,
        });
      }
      const minimumStock = Number.isInteger(
          reminder.medicamentoEstoqueMinimo,
      ) ? reminder.medicamentoEstoqueMinimo : null;
      if (restoredStock !== null &&
          minimumStock !== null &&
          restoredStock > minimumStock &&
          lowStockAlertSnapshot?.exists) {
        const nowTimestamp = admin.firestore.Timestamp.now();
        transaction.update(lowStockAlertRef, {
          status: "resolved",
          responsavelId: uid,
          resolvidoEm: nowTimestamp,
          resolucao: "Estoque restaurado ao desfazer confirmacao.",
          updatedAt: nowTimestamp,
        });
      }
      return {
        success: true,
        duplicate: false,
        eventId: correctionEventId,
        registeredAt,
        restoredStock,
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("undoReminderConfirmation error:", error);
    throw new HttpsError(
        "internal",
        "Nao foi possivel desfazer a confirmacao.",
    );
  }
});

module.exports = {confirmReminderOccurrence, undoReminderConfirmation};
