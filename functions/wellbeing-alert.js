/* eslint-disable require-jsdoc */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

function caregiverIds(profile) {
  const ids = Array.isArray(profile?.caregiverIds) ?
    profile.caregiverIds.filter((id) => typeof id === "string" && id) :
    [];
  if (typeof profile?.supervisorId === "string" && profile.supervisorId) {
    ids.push(profile.supervisorId);
  }
  const routing = profile?.caregiverRouting &&
    typeof profile.caregiverRouting === "object" ?
    profile.caregiverRouting :
    {};
  return [...new Set(ids)]
      .filter((id) => {
        const types = routing[id]?.alertTypes;
        return !Array.isArray(types) || types.includes("help_request");
      })
      .slice(0, 8);
}

exports.createWellbeingHelpAlert = onDocumentCreated(
    {
      document: "bem_estar_registros/{entryId}",
      region: "southamerica-east1",
      maxInstances: 5,
    },
    async (event) => {
      const entry = event.data?.data() || {};
      if (entry.precisaAjuda !== true || !entry.idosoId) return;

      const db = admin.firestore();
      const entryId = event.params.entryId;
      const alertId = `wellbeing_${entryId}`;
      const alertRef = db.collection("alertas").doc(alertId);
      const createdAt = entry.createdAt?.toDate ?
        entry.createdAt :
        admin.firestore.Timestamp.now();
      const shouldNotify = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(alertRef);
        const existingData = existing.data() || {};
        if (existing.exists) {
          return existingData.status !== "acknowledged" &&
            existingData.status !== "resolved" &&
            existingData.deliveryStatus !== "sent";
        }
        transaction.create(alertRef, {
          id: alertId,
          idosoId: entry.idosoId,
          tipo: "help_request",
          titulo: "Pedido de ajuda",
          mensagem: "A pessoa idosa pediu ajuda no check-in de bem-estar.",
          severidade: 3,
          status: "open",
          origemId: entryId,
          createdAt,
          updatedAt: admin.firestore.Timestamp.now(),
        });
        return true;
      });
      if (!shouldNotify) return;

      const profile = await db.collection("idoso_perfil")
          .doc(entry.idosoId)
          .get();
      const recipients = profile.exists && profile.data()?.status === "active" ?
        caregiverIds(profile.data() || {}) :
        [];
      let sent = 0;
      for (const caregiverId of recipients) {
        const tokenDoc = await db.collection("fcm_tokens")
            .doc(`supervisor_${caregiverId}`)
            .get();
        const token = tokenDoc.data()?.token;
        if (!token) continue;
        try {
          await admin.messaging().send({
            token,
            notification: {
              title: "Pedido de ajuda",
              body: "Abra o Lembrete Amigo para acompanhar.",
            },
            data: {
              type: "help_request",
              elderlyId: String(entry.idosoId),
              alertId,
            },
            android: {priority: "high", ttl: 300000},
            apns: {
              headers: {"apns-priority": "10"},
              payload: {aps: {sound: "default", badge: 1}},
            },
          });
          sent++;
        } catch (error) {
          console.error("createWellbeingHelpAlert send error", error);
        }
      }
      await alertRef.update({
        deliveryStatus: sent > 0 ? "sent" : "token_missing",
        updatedAt: admin.firestore.Timestamp.now(),
      });
    },
);
