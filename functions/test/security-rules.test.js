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
      caregiverIds: [
        "supervisor-a",
        "supervisor-backup",
        "supervisor-viewer",
      ],
      caregiverRoles: {
        "supervisor-a": "primary",
        "supervisor-backup": "backup",
        "supervisor-viewer": "viewer",
      },
    });
    await db.collection("idoso_perfil").doc("elderly-b").set({
      nome: "Pessoa B",
      status: "active",
      supervisorId: "supervisor-b",
      caregiverIds: ["supervisor-b"],
      caregiverRoles: {"supervisor-b": "primary"},
    });
    await db.collection("supervisores").doc("supervisor-a").set({
      nome: "Cuidador A",
      email: "a@example.test",
    });
    await db.collection("supervisores").doc("supervisor-b").set({
      nome: "Cuidador B",
      email: "b@example.test",
    });
    await db.collection("supervisores").doc("supervisor-backup").set({
      nome: "Cuidador Reserva",
      email: "backup@example.test",
    });
    await db.collection("supervisores").doc("supervisor-viewer").set({
      nome: "Observador",
      email: "viewer@example.test",
    });
    await db.collection("supervisores")
        .doc("supervisor-a")
        .collection("idosos")
        .doc("elderly-a")
        .set({role: "primary", linkedAt: now()});
    await db.collection("supervisores")
        .doc("supervisor-backup")
        .collection("idosos")
        .doc("elderly-a")
        .set({role: "backup", linkedAt: now()});
    await db.collection("supervisores")
        .doc("supervisor-b")
        .collection("idosos")
        .doc("elderly-b")
        .set({role: "primary", linkedAt: now()});
    await db.collection("supervisores")
        .doc("supervisor-viewer")
        .collection("idosos")
        .doc("elderly-a")
        .set({role: "viewer", linkedAt: now()});
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
    prioridade: "normal",
    toleranciaMinutos: 30,
    intervaloRepeticaoMinutos: 5,
    maximoRepeticoes: 2,
    avisarCuidador: true,
    medicamentoDose: null,
    medicamentoUnidade: null,
    medicamentoEstoque: null,
    medicamentoEstoqueMinimo: null,
    medicamentoUnidadesPorDose: null,
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

/**
 * Builds an immutable wellbeing entry accepted by the strict schema.
 * @param {string} elderlyId
 * @param {string} id
 * @return {Object}
 */
function validWellbeing(elderlyId, id) {
  return {
    id,
    idosoId: elderlyId,
    humor: 4,
    sintomas: ["Sono"],
    observacao: "Dormi pouco, mas estou bem.",
    transcricao: "Dormi pouco, mas estou bem.",
    precisaAjuda: false,
    createdAt: new Date(),
    createdBy: elderlyId,
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

test("a backup caregiver can access the linked elderly profile", async () => {
  const db = testEnv.authenticatedContext("supervisor-backup").firestore();
  await assertSucceeds(
      db.collection("idoso_perfil").doc("elderly-a").get(),
  );
  await assertFails(
      db.collection("idoso_perfil").doc("elderly-b").get(),
  );
});

test("backup caregiver queries require the array link filter", async () => {
  const db = testEnv.authenticatedContext("supervisor-backup").firestore();
  await assertSucceeds(
      db.collection("idoso_perfil")
          .where("caregiverIds", "array-contains", "supervisor-backup")
          .where("status", "==", "active")
          .get(),
  );
  await assertFails(db.collection("idoso_perfil").get());
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


test("viewer caregivers have read-only access", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      ownerDb.collection("lembretes")
          .doc("viewer-readable")
          .set(validReminder("elderly-a", "viewer-readable")),
  );

  const viewerDb =
    testEnv.authenticatedContext("supervisor-viewer").firestore();
  await assertSucceeds(
      viewerDb.collection("idoso_perfil").doc("elderly-a").get(),
  );
  await assertSucceeds(
      viewerDb.collection("lembretes").doc("viewer-readable").get(),
  );
  await assertFails(
      viewerDb.collection("idoso_perfil").doc("elderly-a").update({
        nome: "Alteração indevida",
      }),
  );
  await assertFails(
      viewerDb.collection("lembretes")
          .doc("viewer-write")
          .set(validReminder("elderly-a", "viewer-write")),
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

test("authorized profile fields can still be updated", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      ownerDb.collection("idoso_perfil").doc("elderly-a").update({
        nome: "Pessoa A atualizada",
        updatedAt: now(),
      }),
  );
});

test("clients cannot add themselves to a caregiver network", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(
      ownerDb.collection("idoso_perfil").doc("elderly-a").update({
        caregiverIds: ["supervisor-a", "attacker"],
        caregiverRoles: {
          "supervisor-a": "primary",
          "attacker": "backup",
        },
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

test("an owner can create reminders", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      ownerDb.collection("lembretes")
          .doc("reminder-owner")
          .set(validReminder("elderly-a", "reminder-owner")),
  );
});

test("a primary caregiver can create linked reminders", async () => {
  const linkedDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      linkedDb.collection("lembretes")
          .doc("reminder-linked")
          .set(validReminder("elderly-a", "reminder-linked")),
  );
});

test("a backup caregiver can create linked reminders", async () => {
  const backupDb =
    testEnv.authenticatedContext("supervisor-backup").firestore();
  const ref = backupDb.collection("lembretes").doc("reminder-backup");
  await assertSucceeds(
      ref.set(validReminder("elderly-a", "reminder-backup")),
  );
  await assertSucceeds(ref.update({titulo: "Beber agua agora"}));
});

test("an unrelated caregiver cannot create reminders", async () => {
  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  await assertFails(
      attackerDb.collection("lembretes")
          .doc("reminder-attack")
          .set(validReminder("elderly-a", "reminder-attack")),
  );
});

test("reminder update cannot bypass the strict schema", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = ownerDb.collection("lembretes").doc("reminder-strict");
  await assertSucceeds(
      ref.set(validReminder("elderly-a", "reminder-strict")),
  );
  await assertSucceeds(ref.update({status: "adiado"}));
  await assertFails(ref.update({prioridade: "admin"}));
  await assertFails(ref.update({medicamentoDose: "x".repeat(10000)}));
  await assertFails(ref.update({campoInesperado: true}));
});

test("reminders are archived with a typed timestamp", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const archivedRef = ownerDb.collection("lembretes").doc("archive-valid");
  const invalidRef = ownerDb.collection("lembretes").doc("archive-invalid");
  await assertSucceeds(
      archivedRef.set(validReminder("elderly-a", "archive-valid")),
  );
  await assertSucceeds(
      invalidRef.set(validReminder("elderly-a", "archive-invalid")),
  );

  await assertSucceeds(archivedRef.update({
    arquivado: true,
    arquivadoEm: now(),
  }));
  await assertFails(invalidRef.update({arquivado: true}));
  await assertFails(archivedRef.delete());
});

test("protected confirmation bypass is denied", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const photoRef = ownerDb.collection("lembretes").doc("photo-secure");
  await assertSucceeds(
      photoRef.set({
        ...validReminder("elderly-a", "photo-secure"),
        modoConfirmacao: "foto",
        opcoesAdiamentoMinutos: [5, 10],
        maximoAdiamentos: 2,
      }),
  );
  await assertFails(
      photoRef.update({
        status: "concluido_com_foto",
        concluido: true,
        concluidoComFoto: true,
        medicamentoFotoPath: "https://example.test/photo.jpg",
      }),
  );

  const caregiverRef = ownerDb
      .collection("lembretes")
      .doc("caregiver-secure");
  await assertSucceeds(
      caregiverRef.set({
        ...validReminder("elderly-a", "caregiver-secure"),
        modoConfirmacao: "cuidador",
      }),
  );
  await assertFails(
      caregiverRef.update({
        status: "confirmado_pelo_cuidador",
        concluido: true,
      }),
  );
});

test("snooze options use a small allowlist and bounded count", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      ownerDb.collection("lembretes").doc("snooze-valid").set({
        ...validReminder("elderly-a", "snooze-valid"),
        opcoesAdiamentoMinutos: [5, 15, 30],
        maximoAdiamentos: 3,
      }),
  );
  await assertFails(
      ownerDb.collection("lembretes").doc("snooze-invalid").set({
        ...validReminder("elderly-a", "snooze-invalid"),
        opcoesAdiamentoMinutos: [7, 999],
        maximoAdiamentos: 20,
      }),
  );
});

test("confirmation audit events are immutable", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const eventRef = ownerDb
      .collection("lembrete_eventos")
      .doc("confirm_reminder_20260803_1030");
  await assertSucceeds(
      eventRef.set({
        id: "confirm_reminder_20260803_1030",
        lembreteId: "reminder",
        titulo: "Beber agua",
        categoria: "hidratacao",
        status: "concluido",
        registradoEm: now(),
        idosoId: "elderly-a",
        ocorrenciaChave: "reminder_20260803_1030",
        metodoConfirmacao: "botao",
        atorPapel: "elderly",
      }),
  );
  await assertFails(eventRef.update({observacao: "alterado"}));
  await assertFails(eventRef.delete());
  await assertFails(
      ownerDb.collection("lembrete_eventos").doc("bad-event").set({
        id: "bad-event",
        lembreteId: "reminder",
        titulo: "Beber agua",
        categoria: "hidratacao",
        status: "concluido",
        registradoEm: now(),
        idosoId: "elderly-a",
        metodoConfirmacao: "admin",
      }),
  );
});

test("audit event authority cannot be forged", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const caregiverDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  const baseEvent = {
    lembreteId: "reminder",
    titulo: "Beber agua",
    categoria: "hidratacao",
    status: "concluido",
    registradoEm: now(),
    idosoId: "elderly-a",
    ocorrenciaChave: "reminder_20260803_1030",
    metodoConfirmacao: "botao",
  };

  await assertFails(
      ownerDb.collection("lembrete_eventos").doc("forged-supervisor").set({
        ...baseEvent,
        id: "forged-supervisor",
        atorPapel: "supervisor",
      }),
  );
  await assertFails(
      ownerDb.collection("lembrete_eventos").doc("forged-photo").set({
        ...baseEvent,
        id: "forged-photo",
        status: "concluido_com_foto",
        metodoConfirmacao: "foto",
        atorPapel: "elderly",
        fotoConfirmacaoPath: "https://example.test/proof.jpg",
      }),
  );
  await assertSucceeds(
      caregiverDb.collection("lembrete_eventos").doc("caregiver-event").set({
        ...baseEvent,
        id: "caregiver-event",
        atorPapel: "supervisor",
      }),
  );
  await assertFails(
      caregiverDb.collection("lembrete_eventos").doc("forged-elderly").set({
        ...baseEvent,
        id: "forged-elderly",
        atorPapel: "elderly",
      }),
  );
});

test("alarm test diagnostics accept only typed fields", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = ownerDb.collection("device_diagnostics").doc("elderly-a");
  await assertSucceeds(ref.set({
    barriers: [],
    updatedAt: now(),
    lastAlarmTestAt: now(),
    lastAlarmTestSuccessful: true,
  }));
  await assertFails(ref.update({lastAlarmTestSuccessful: "yes"}));
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

test("wellbeing entries are scoped and immutable", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = ownerDb.collection("bem_estar_registros").doc("checkin-a");
  await assertSucceeds(ref.set(validWellbeing("elderly-a", "checkin-a")));

  const caregiverDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      caregiverDb.collection("bem_estar_registros").doc("checkin-a").get(),
  );
  await assertSucceeds(
      caregiverDb.collection("bem_estar_registros")
          .where("idosoId", "==", "elderly-a")
          .get(),
  );

  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  await assertFails(
      attackerDb.collection("bem_estar_registros").doc("checkin-a").get(),
  );
  await assertFails(ref.update({humor: 1}));
  await assertFails(ref.delete());
});

test("caregivers cannot forge wellbeing entries", async () => {
  const caregiverDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertFails(
      caregiverDb.collection("bem_estar_registros").doc("forged").set({
        ...validWellbeing("elderly-a", "forged"),
        createdBy: "supervisor-a",
      }),
  );
});

test("wellbeing schema rejects unexpected and oversized values", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(
      ownerDb.collection("bem_estar_registros").doc("extra-field").set({
        ...validWellbeing("elderly-a", "extra-field"),
        admin: true,
      }),
  );
  await assertFails(
      ownerDb.collection("bem_estar_registros").doc("bad-symptom").set({
        ...validWellbeing("elderly-a", "bad-symptom"),
        sintomas: ["x".repeat(10000)],
      }),
  );
  await assertFails(
      ownerDb.collection("bem_estar_registros").doc("bad-note").set({
        ...validWellbeing("elderly-a", "bad-note"),
        observacao: "x".repeat(1001),
      }),
  );
});

test("stock history is linked-readable but server-write-only", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("estoque_movimentos")
        .doc("consume-occurrence").set({
          id: "consume-occurrence",
          idosoId: "elderly-a",
          lembreteId: "medicine-a",
          tipo: "consumo",
          quantidade: 1,
          estoqueAnterior: 20,
          estoquePosterior: 19,
          ocorrenciaChave: "medicine-a_20260803_1030",
          createdAt: new Date(),
          createdBy: "elderly-a",
        });
  });

  const linkedDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      linkedDb.collection("estoque_movimentos")
          .doc("consume-occurrence").get(),
  );
  await assertFails(
      linkedDb.collection("estoque_movimentos").doc("forged").set({
        id: "forged",
        idosoId: "elderly-a",
        lembreteId: "medicine-a",
        tipo: "reposicao",
        quantidade: 1000,
        estoqueAnterior: 0,
        estoquePosterior: 1000,
        createdAt: new Date(),
        createdBy: "supervisor-a",
      }),
  );

  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  await assertFails(
      attackerDb.collection("estoque_movimentos")
          .doc("consume-occurrence").get(),
  );
});

test("care alerts are linked-readable but server-write-only", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("alertas").doc("alert-a").set({
      id: "alert-a",
      idosoId: "elderly-a",
      tipo: "help_request",
      titulo: "Pedido de ajuda",
      mensagem: "A pessoa idosa pediu ajuda.",
      severidade: 3,
      status: "open",
      createdAt: new Date(),
    });
  });

  const linkedDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  const alertRef = linkedDb.collection("alertas").doc("alert-a");
  await assertSucceeds(alertRef.get());
  await assertFails(alertRef.update({status: "resolved"}));
  await assertFails(
      linkedDb.collection("alertas").doc("forged-alert").set({
        idosoId: "elderly-a",
        status: "resolved",
      }),
  );

  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  await assertFails(attackerDb.collection("alertas").doc("alert-a").get());
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

  const backupStorage =
    testEnv.authenticatedContext("supervisor-backup").storage();
  await assertSucceeds(backupStorage.ref(pathName).getDownloadURL());

  const viewerStorage =
    testEnv.authenticatedContext("supervisor-viewer").storage();
  await assertSucceeds(viewerStorage.ref(pathName).getDownloadURL());
  await assertFails(
      viewerStorage.ref("perfis/elderly-a/viewer-write.jpg").put(
          new Uint8Array([1, 2, 3]),
          {contentType: "image/jpeg"},
      ),
  );

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

