/* eslint-disable require-jsdoc */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  getFirestore, Timestamp,
} = require("firebase-admin/firestore");

const CALL_OPTIONS = {cors: true, enforceAppCheck: true};

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Entre na conta.");
  }
  return request.auth.uid;
}

function requireId(value, field, maxLength = 160) {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > maxLength ||
    !/^[a-zA-Z0-9_-]+$/.test(value)
  ) {
    throw new HttpsError("invalid-argument", `${field} invalido.`);
  }
  return value;
}

function optionalText(value, field, maxLength) {
  if (value == null || value === "") return "";
  if (typeof value !== "string" || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} invalido.`);
  }
  return value.trim();
}

function linkedCaregivers(profile) {
  const values = Array.isArray(profile?.caregiverIds) ?
    profile.caregiverIds.filter((id) => typeof id === "string" && id) :
    [];
  if (typeof profile?.supervisorId === "string" && profile.supervisorId) {
    values.push(profile.supervisorId);
  }
  return [...new Set(values)].slice(0, 8);
}

function caregiverCanManage(profile, uid) {
  if (!linkedCaregivers(profile).includes(uid)) return false;
  if (profile?.supervisorId === uid) return true;
  const roles = profile?.caregiverRoles;
  const role = roles && typeof roles === "object" && !Array.isArray(roles) ?
    roles[uid] :
    null;
  return ["primary", "backup", "family"].includes(role);
}

async function assertCanManage(transaction, elderlyId, uid) {
  const profileRef = getFirestore()
      .collection("idoso_perfil")
      .doc(elderlyId);
  const profileSnapshot = await transaction.get(profileRef);
  const profile = profileSnapshot.data() || {};
  if (!profileSnapshot.exists ||
      profile.status !== "active" ||
      !caregiverCanManage(profile, uid)) {
    throw new HttpsError(
        "permission-denied",
        "Voce nao pode alterar dados desta pessoa.",
    );
  }
}

async function checkRateLimit(uid, functionName, maxCalls = 30) {
  const db = getFirestore();
  const now = Date.now();
  const ref = db.collection("_rate_limits").doc(`${functionName}_${uid}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    const windowStart = Number(data.windowStart) || 0;
    const count = Number(data.count) || 0;
    if (now - windowStart > 60000) {
      transaction.set(ref, {windowStart: now, count: 1});
      return;
    }
    if (count >= maxCalls) {
      throw new HttpsError(
          "resource-exhausted",
          "Muitas tentativas. Aguarde um minuto.",
      );
    }
    transaction.update(ref, {count: count + 1});
  });
}

const acknowledgeCareAlert = onCall(CALL_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "acknowledgeCareAlert");
  const alertId = requireId(request.data?.alertId, "alertId");
  const db = getFirestore();
  const alertRef = db.collection("alertas").doc(alertId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(alertRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Pendencia nao encontrada.");
    }
    const alert = snapshot.data() || {};
    const elderlyId = requireId(alert.idosoId, "alert.idosoId", 128);
    await assertCanManage(transaction, elderlyId, uid);
    if (alert.status === "resolved") {
      return {success: true, status: "resolved"};
    }
    const now = Timestamp.now();
    transaction.update(alertRef, {
      status: "acknowledged",
      responsavelId: uid,
      assumidoEm: now,
      updatedAt: now,
    });
    return {success: true, status: "acknowledged"};
  });
});

const resolveCareAlert = onCall(CALL_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "resolveCareAlert");
  const alertId = requireId(request.data?.alertId, "alertId");
  const resolution = optionalText(
      request.data?.resolution,
      "resolution",
      500,
  );
  const db = getFirestore();
  const alertRef = db.collection("alertas").doc(alertId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(alertRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Pendencia nao encontrada.");
    }
    const alert = snapshot.data() || {};
    const elderlyId = requireId(alert.idosoId, "alert.idosoId", 128);
    await assertCanManage(transaction, elderlyId, uid);
    if (alert.status === "resolved") {
      return {success: true, status: "resolved"};
    }
    const now = Timestamp.now();
    transaction.update(alertRef, {
      status: "resolved",
      responsavelId: alert.responsavelId || uid,
      resolvidoEm: now,
      resolucao: resolution,
      updatedAt: now,
    });
    return {success: true, status: "resolved"};
  });
});

const replenishMedicationStock = onCall(CALL_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "replenishMedicationStock", 20);
  const reminderId = requireId(request.data?.reminderId, "reminderId", 128);
  const requestId = requireId(request.data?.requestId, "requestId", 128);
  const quantity = Number(request.data?.quantity);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 1000000) {
    throw new HttpsError("invalid-argument", "Quantidade invalida.");
  }
  const note = optionalText(request.data?.note, "note", 300);
  const expirationText = optionalText(
      request.data?.expirationDate,
      "expirationDate",
      10,
  );
  let expiration = null;
  if (expirationText) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(expirationText)) {
      throw new HttpsError(
          "invalid-argument",
          "A validade deve usar o formato AAAA-MM-DD.",
      );
    }
    const parsed = new Date(`${expirationText}T12:00:00.000Z`);
    if (Number.isNaN(parsed.getTime())) {
      throw new HttpsError("invalid-argument", "Validade invalida.");
    }
    expiration = Timestamp.fromDate(parsed);
  }

  const db = getFirestore();
  const reminderRef = db.collection("lembretes").doc(reminderId);
  const movementId = `replenish_${reminderId}_${requestId}`;
  const movementRef = db.collection("estoque_movimentos").doc(movementId);
  const lowStockRef = db.collection("alertas").doc(`low_stock_${reminderId}`);

  return db.runTransaction(async (transaction) => {
    const reminderSnapshot = await transaction.get(reminderRef);
    const movementSnapshot = await transaction.get(movementRef);
    const lowStockSnapshot = await transaction.get(lowStockRef);
    if (!reminderSnapshot.exists) {
      throw new HttpsError("not-found", "Medicamento nao encontrado.");
    }
    const reminder = reminderSnapshot.data() || {};
    const elderlyId = requireId(reminder.idosoId, "reminder.idosoId", 128);
    await assertCanManage(transaction, elderlyId, uid);
    if (movementSnapshot.exists) {
      return {
        success: true,
        duplicate: true,
        remainingStock: movementSnapshot.data()?.estoquePosterior ?? 0,
      };
    }
    if (reminder.categoria !== "medicacao") {
      throw new HttpsError(
          "failed-precondition",
          "Este lembrete nao e de medicamento.",
      );
    }
    const previousStock = Number.isInteger(reminder.medicamentoEstoque) ?
      reminder.medicamentoEstoque :
      0;
    const remainingStock = previousStock + quantity;
    if (remainingStock > 1000000) {
      throw new HttpsError("invalid-argument", "Estoque acima do limite.");
    }
    const now = Timestamp.now();
    transaction.update(reminderRef, {medicamentoEstoque: remainingStock});
    const movement = {
      id: movementId,
      idosoId: elderlyId,
      lembreteId: reminderId,
      tipo: "reposicao",
      quantidade: quantity,
      estoqueAnterior: previousStock,
      estoquePosterior: remainingStock,
      createdAt: now,
      createdBy: uid,
    };
    if (note) movement.observacao = note;
    if (expiration) movement.validade = expiration;
    transaction.create(movementRef, movement);
    if (lowStockSnapshot.exists) {
      transaction.update(lowStockRef, {
        status: "resolved",
        responsavelId: uid,
        resolvidoEm: now,
        resolucao: "Estoque reposto.",
        updatedAt: now,
      });
    }
    return {success: true, duplicate: false, remainingStock};
  });
});

module.exports = {
  acknowledgeCareAlert,
  resolveCareAlert,
  replenishMedicationStock,
};
