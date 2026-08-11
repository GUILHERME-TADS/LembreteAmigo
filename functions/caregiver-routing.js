/* eslint-disable require-jsdoc */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const CALL_OPTIONS = {cors: true, enforceAppCheck: true};
const ALLOWED_ALERT_TYPES = new Set([
  "missed_reminder",
  "help_request",
  "device_barrier",
  "low_stock",
]);

function requireId(value, field) {
  if (
    typeof value !== "string" ||
    !/^[a-zA-Z0-9_-]{1,128}$/.test(value)
  ) {
    throw new HttpsError("invalid-argument", `${field} inválido.`);
  }
  return value;
}

function requireTime(value, field) {
  if (typeof value !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw new HttpsError("invalid-argument", `${field} deve usar HH:mm.`);
  }
  return value;
}

function caregiverIds(profile) {
  const ids = Array.isArray(profile.caregiverIds) ? profile.caregiverIds : [];
  if (typeof profile.supervisorId === "string") ids.push(profile.supervisorId);
  return [...new Set(ids)].filter(Boolean).slice(0, 8);
}

exports.updateCaregiverRouting = onCall(CALL_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na conta.");

  const input = request.data || {};
  const elderlyId = requireId(input.elderlyId, "elderlyId");
  const caregiverId = requireId(input.caregiverId, "caregiverId");
  const priority = Number(input.priority);
  if (!Number.isInteger(priority) || priority < 1 || priority > 8) {
    throw new HttpsError("invalid-argument", "Prioridade inválida.");
  }
  const availableStart = requireTime(input.availableStart, "availableStart");
  const availableEnd = requireTime(input.availableEnd, "availableEnd");
  const alertTypes = Array.isArray(input.alertTypes) ?
    [...new Set(input.alertTypes)] :
    [];
  if (
    alertTypes.length === 0 ||
    alertTypes.length > 4 ||
    alertTypes.some(
        (type) => typeof type !== "string" || !ALLOWED_ALERT_TYPES.has(type),
    )
  ) {
    throw new HttpsError("invalid-argument", "Tipos de alerta inválidos.");
  }

  const db = admin.firestore();
  const profileRef = db.collection("idoso_perfil").doc(elderlyId);
  const legacyRef = db.collection("idosos").doc(elderlyId);
  await db.runTransaction(async (transaction) => {
    const [profileSnap, legacySnap] = await Promise.all([
      transaction.get(profileRef),
      transaction.get(legacyRef),
    ]);
    if (!profileSnap.exists) {
      throw new HttpsError("not-found", "Perfil não encontrado.");
    }
    const profile = profileSnap.data() || {};
    const linkedIds = caregiverIds(profile);
    if (!linkedIds.includes(caregiverId)) {
      throw new HttpsError("failed-precondition", "Cuidador não vinculado.");
    }
    const roles =
      profile.caregiverRoles && typeof profile.caregiverRoles === "object" ?
        profile.caregiverRoles :
        {};
    const canManage =
      uid === elderlyId ||
      profile.supervisorId === uid ||
      roles[uid] === "primary";
    if (!canManage) {
      throw new HttpsError(
          "permission-denied",
          "Somente a pessoa idosa ou o cuidador principal " +
          "pode alterar a ordem.",
      );
    }

    const currentRouting =
      profile.caregiverRouting && typeof profile.caregiverRouting === "object" ?
        profile.caregiverRouting :
        {};
    const nextRouting = {...currentRouting};
    nextRouting[caregiverId] = {
      priority,
      availableStart,
      availableEnd,
      alertTypes,
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: uid,
    };
    const patch = {
      caregiverRouting: nextRouting,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    transaction.update(profileRef, patch);
    if (legacySnap.exists) transaction.update(legacyRef, patch);
  });

  return {success: true};
});
