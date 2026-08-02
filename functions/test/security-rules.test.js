const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "lembreteamigo-26fd0";
let testEnv;

/** @return {string} Current ISO timestamp. */
const now = () => new Date().toISOString();

/** Seeds the canonical relationship graph used by security tests. */
async function seedProfiles() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection("idoso_perfil").doc("elderly-a").set({
      nome: "Pessoa A",
      status: "active",
      supervisorId: "supervisor-a",
    });
    await db.collection("idoso_perfil").doc("elderly-b").set({
      nome: "Pessoa B",
      status: "active",
      supervisorId: "supervisor-b",
    });
    await db.collection("supervisores").doc("supervisor-a").set({
      nome: "Cuidador A",
      email: "a@example.test",
    });
    await db.collection("supervisores").doc("supervisor-b").set({
      nome: "Cuidador B",
      email: "b@example.test",
    });
  });
}

/**
 * Builds a reminder accepted by the strict schema.
 * @param {string} elderlyId
 * @param {string} id
 * @return {Object}
 */
function validReminder(elderlyId, id) {
  return {
    id,
    titulo: "Beber agua",
    horarioHour: 10,
    horarioMinute: 30,
    originalHorarioHour: 10,
    originalHorarioMinute: 30,
    categoria: "hidratacao",
    audioPath: null,
    concluido: false,
    concluidoComFoto: false,
    criadoEm: now(),
    medicamentoFotoPath: null,
    idosoId: elderlyId,
    status: "pendente",
    repeteTodosOsDias: true,
    recorrenciaSemanal: false,
    recorrenciaMensal: false,
    recorrenciaIntervalo: false,
    lembreteUnico: false,
    diasSemana: [],
    diaMes: null,
    intervaloHoras: null,
    recorrencia: "diaria",
    dataInicio: null,
    dataFim: null,
    isUsoContinuo: false,
    medicamentoInstrucoes: null,
    medicamentoAudioTexto: null,
  };
}

/**
 * Builds a message accepted by the strict schema.
 * @param {string} elderlyId
 * @param {string} id
 * @param {string} senderRole
 * @return {Object}
 */
function validMessage(elderlyId, id, senderRole) {
  return {
    id,
    idosoId: elderlyId,
    nomeIdoso: "Pessoa A",
    senderRole,
    tipo: "texto",
    texto: "Tudo bem?",
    audioPath: null,
    criadoEm: now(),
    lido: false,
    duracaoSegundos: null,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "..", "firestore.rules"),
          "utf8",
      ),
    },
    storage: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "..", "storage.rules"),
          "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedProfiles();
});

after(async () => {
  await testEnv.cleanup();
});

test("unauthenticated users cannot read private profiles", async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(db.collection("idoso_perfil").doc("elderly-a").get());
});

test("an elderly user can read only their own profile", async () => {
  const db = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      db.collection("idoso_perfil").doc("elderly-a").get(),
  );
  await assertFails(
      db.collection("idoso_perfil").doc("elderly-b").get(),
  );
});

test("a self-created supervisor profile grants no global access", async () => {
  const db = testEnv.authenticatedContext(
      "attacker",
      {email: "attacker@example.test"},
  ).firestore();
  await assertSucceeds(
      db.collection("supervisores").doc("attacker").set({
        nome: "Atacante",
        email: "attacker@example.test",
      }),
  );
  await assertFails(
      db.collection("idoso_perfil").doc("elderly-a").get(),
  );
});

test("a supervisor reads only the exact linked profile", async () => {
  const db = testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      db.collection("idoso_perfil").doc("elderly-a").get(),
  );
  await assertFails(
      db.collection("idoso_perfil").doc("elderly-b").get(),
  );
});

test("supervisor queries require exact link filters", async () => {
  const db = testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      db.collection("idoso_perfil")
          .where("supervisorId", "==", "supervisor-a")
          .where("status", "==", "active")
          .get(),
  );
  await assertFails(
      db.collection("idoso_perfil").get(),
  );
});


test("clients cannot change relationship authority fields", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(
      ownerDb.collection("idoso_perfil").doc("elderly-a").update({
        supervisorId: "attacker",
        status: "active",
      }),
  );

  const supervisorDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertFails(
      supervisorDb.collection("idoso_perfil").doc("elderly-a").update({
        supervisorId: null,
        status: "pending",
      }),
  );
});

test("clients cannot create relationship index documents", async () => {
  const db = testEnv.authenticatedContext("supervisor-a").firestore();
  await assertFails(
      db.collection("supervisores")
          .doc("supervisor-a")
          .collection("idosos")
          .doc("elderly-b")
          .set({linkedAt: now()}),
  );
});

test("reminders are limited to owner and exact linked supervisor", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      ownerDb.collection("lembretes")
          .doc("reminder-owner")
          .set(validReminder("elderly-a", "reminder-owner")),
  );

  const linkedDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      linkedDb.collection("lembretes")
          .doc("reminder-linked")
          .set(validReminder("elderly-a", "reminder-linked")),
  );

  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  await assertFails(
      attackerDb.collection("lembretes")
          .doc("reminder-attack")
          .set(validReminder("elderly-a", "reminder-attack")),
  );
});

test("message sender roles cannot be forged", async () => {
  const elderlyDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      elderlyDb.collection("mensagens")
          .doc("message-correct")
          .set(validMessage("elderly-a", "message-correct", "elderly")),
  );
  await assertFails(
      elderlyDb.collection("mensagens")
          .doc("message-forged")
          .set(validMessage("elderly-a", "message-forged", "supervisor")),
  );
});

test("video calls reject a mismatched supervisor identity", async () => {
  const db = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(
      db.collection("video_calls").doc("call-forged").set({
        roomName: "call_forged",
        idosoId: "elderly-a",
        supervisorId: "supervisor-b",
        status: "ringing",
        initiatedBy: "elderly",
        callType: "video",
        startedAt: now(),
      }),
  );
});

test("server-only pairing collections reject every client", async () => {
  const db = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(db.collection("pairing_codes").doc("hash").get());
  await assertFails(
      db.collection("pairing_codes").doc("hash").set({
        elderlyId: "elderly-a",
      }),
  );
});

test("profile photos are private and exact-link scoped", async () => {
  const pathName = "perfis/elderly-a/profile.jpg";
  const ownerStorage = testEnv.authenticatedContext("elderly-a").storage();
  await assertSucceeds(
      ownerStorage.ref(pathName).put(
          new Uint8Array([1, 2, 3]),
          {contentType: "image/jpeg"},
      ),
  );

  const publicStorage = testEnv.unauthenticatedContext().storage();
  await assertFails(publicStorage.ref(pathName).getDownloadURL());

  const linkedStorage =
    testEnv.authenticatedContext("supervisor-a").storage();
  await assertSucceeds(linkedStorage.ref(pathName).getDownloadURL());

  const otherStorage =
    testEnv.authenticatedContext("supervisor-b").storage();
  await assertFails(otherStorage.ref(pathName).getDownloadURL());
});

test("generic or missing media MIME types are rejected", async () => {
  const storage = testEnv.authenticatedContext("elderly-a").storage();
  await assertFails(
      storage.ref("reminder_photos/elderly-a/unsafe.jpg").put(
          new Uint8Array([1, 2, 3]),
          {contentType: "application/octet-stream"},
      ),
  );
});

