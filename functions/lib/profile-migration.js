/* eslint-disable require-jsdoc */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  FieldValue,
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");

const CALL_OPTIONS = {cors: true, enforceAppCheck: true};
const ID_PATTERN = /^[a-zA-Z0-9_-]{1,128}$/;
const TIME_PATTERN = /^([01][0-9]|2[0-3]):[0-5][0-9]$/;
const ALLOWED_ALERT_TYPES = new Set([
  "missed_reminder",
  "help_request",
  "device_barrier",
  "low_stock",
]);

function optionalString(target, source, field, maxLength) {
  const value = source[field];
  if (typeof value === "string" && value.length <= maxLength) {
    target[field] = value.trim();
  }
}

function optionalInteger(target, source, field, min, max) {
  const value = source[field];
  if (Number.isInteger(value) && value >= min && value <= max) {
    target[field] = value;
  }
}

function optionalNumber(target, source, field, min, max) {
  const value = source[field];
  if (typeof value === "number" && value >= min && value <= max) {
    target[field] = value;
  }
}

function optionalDate(target, source, field) {
  const value = source[field];
  if (
    value instanceof Timestamp ||
    (
      typeof value === "string" &&
      value.length >= 10 &&
      value.length <= 40 &&
      /^[0-9]{4}-[0-9]{2}-[0-9]{2}.*$/.test(value)
    )
  ) {
    target[field] = value;
  }
}

function normalizeCaregiverRouting(source, caregiverIds) {
  const routing = source.caregiverRouting;
  if (!routing || typeof routing !== "object" || Array.isArray(routing)) {
    return undefined;
  }

  const normalized = {};
  for (const caregiverId of caregiverIds) {
    const entry = routing[caregiverId];
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;

    const priority = entry.priority;
    const start = entry.availableStart;
    const end = entry.availableEnd;
    const alertTypes = Array.isArray(entry.alertTypes) ?
      [...new Set(entry.alertTypes)].filter(
          (type) => typeof type === "string" && ALLOWED_ALERT_TYPES.has(type),
      ).slice(0, 4) :
      [];
    if (
      !Number.isInteger(priority) ||
      priority < 1 ||
      priority > 8 ||
      typeof start !== "string" ||
      !TIME_PATTERN.test(start) ||
      typeof end !== "string" ||
      !TIME_PATTERN.test(end) ||
      alertTypes.length === 0
    ) {
      continue;
    }
    normalized[caregiverId] = {
      priority,
      availableStart: start,
      availableEnd: end,
      alertTypes,
      ...(ID_PATTERN.test(entry.updatedBy || "") ?
        {updatedBy: entry.updatedBy} :
        {}),
      ...(entry.updatedAt instanceof Timestamp ?
        {updatedAt: entry.updatedAt} :
        {}),
    };
  }
  return Object.keys(normalized).length > 0 ? normalized : undefined;
}

function normalizeLegacyProfile(source) {
  const data = source && typeof source === "object" ? source : {};
  const normalized = {};
  optionalString(normalized, data, "nome", 120);
  optionalInteger(normalized, data, "idade", 0, 130);
  optionalString(normalized, data, "telefone", 30);
  optionalString(normalized, data, "ambulancia_telefone", 30);
  optionalString(normalized, data, "dataNascimento", 30);
  optionalString(normalized, data, "endereco", 300);
  optionalString(normalized, data, "fotoPath", 2048);
  optionalDate(normalized, data, "createdAt");
  optionalDate(normalized, data, "lastSeen");
  optionalNumber(normalized, data, "alex_voice_rate", 0.1, 1.0);
  optionalNumber(normalized, data, "alex_voice_pitch", 0.5, 2.0);
  if (typeof data.always_listening_enabled === "boolean") {
    normalized.always_listening_enabled = data.always_listening_enabled;
  }

  const caregiverIds = [
    ...(Array.isArray(data.caregiverIds) ? data.caregiverIds : []),
    data.supervisorId,
  ].filter((id) => typeof id === "string" && ID_PATTERN.test(id));
  normalized.caregiverIds = [...new Set(caregiverIds)].slice(0, 8);

  const sourceRoles =
    data.caregiverRoles &&
    typeof data.caregiverRoles === "object" &&
    !Array.isArray(data.caregiverRoles) ?
      data.caregiverRoles :
      {};
  normalized.caregiverRoles = {};
  for (const caregiverId of normalized.caregiverIds) {
    const role = sourceRoles[caregiverId];
    normalized.caregiverRoles[caregiverId] =
      ["primary", "backup", "family", "viewer"].includes(role) ?
        role :
        "backup";
  }
  const requestedSupervisor = data.supervisorId;
  normalized.supervisorId =
    typeof requestedSupervisor === "string" &&
    normalized.caregiverIds.includes(requestedSupervisor) ?
      requestedSupervisor :
      normalized.caregiverIds[0] || null;
  if (normalized.supervisorId) {
    normalized.caregiverRoles[normalized.supervisorId] = "primary";
  }
  normalized.status =
    data.status === "inactive" ?
      "inactive" :
      normalized.caregiverIds.length > 0 ? "active" : "pending";

  const routing = normalizeCaregiverRouting(data, normalized.caregiverIds);
  if (routing) normalized.caregiverRouting = routing;
  return normalized;
}

const migrateLegacyElderlyProfile = onCall(CALL_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na conta.");

  const db = getFirestore();
  const canonicalRef = db.collection("idoso_perfil").doc(uid);
  const legacyRef = db.collection("idosos").doc(uid);
  return db.runTransaction(async (transaction) => {
    const [canonicalSnapshot, legacySnapshot] = await Promise.all([
      transaction.get(canonicalRef),
      transaction.get(legacyRef),
    ]);
    if (canonicalSnapshot.exists || !legacySnapshot.exists) {
      return {migrated: false};
    }

    const profile = normalizeLegacyProfile(legacySnapshot.data() || {});
    profile.updatedAt = FieldValue.serverTimestamp();
    if (!profile.createdAt) profile.createdAt = FieldValue.serverTimestamp();
    transaction.create(canonicalRef, profile);
    return {migrated: true};
  });
});

module.exports = {
  migrateLegacyElderlyProfile,
  normalizeLegacyProfile,
};
