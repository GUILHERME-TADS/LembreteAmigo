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
    medicamentoFormato: null,
    medicamentoCor: null,
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
  await assertSucceeds(ref.update({titulo: "Beber agua agora"}));
  await assertFails(ref.update({titulo: "x".repeat(201)}));
  await assertFails(ref.update({horarioHour: 25}));
  await assertFails(ref.update({categoria: "administrador"}));
  await assertFails(ref.update({diasSemana: [1, 8]}));
  await assertFails(ref.update({idosoId: "elderly-b"}));
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
  await assertFails(
      ownerDb.collection("lembretes").doc("archive-create-invalid").set({
        ...validReminder("elderly-a", "archive-create-invalid"),
        arquivado: true,
      }),
  );
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
    barriers: [{
      type: "lowBattery",
      severity: "warning",
      title: "Bateria baixa",
      message: "Conecte o aparelho ao carregador.",
      detectedAt: now(),
      priority: 70,
      value: 15,
    }],
    updatedAt: now(),
    lastAlarmTestAt: now(),
    lastAlarmTestSuccessful: true,
  }));
  await assertSucceeds(ref.update({
    batteryLevel: 85,
    updatedAt: now(),
  }));
  await assertFails(ref.update({lastAlarmTestSuccessful: "yes"}));
  await assertFails(ref.update({unexpectedAdminFlag: true}));
  await assertFails(ref.update({
    barriers: [{
      type: "lowBattery",
      severity: "warning",
      title: "Bateria baixa",
      message: "Conecte o aparelho ao carregador.",
      detectedAt: now(),
      priority: 70,
      value: 15,
      arbitraryPayload: "x".repeat(5000),
    }],
  }));
});

test("unused health metrics remain server-only", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertFails(
      ownerDb.collection("health_metrics").doc("elderly-a").set({
        metrics: {heartRate: 72},
        updatedAt: now(),
      }),
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

test(
    "an owner can create a full Flutter-generated reminder payload",
    async () => {
      const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
      const reminderId = "1787407613304";
      const flutterPayload = {
        id: reminderId,
        titulo: "Tomar Remedio",
        horarioHour: 14,
        horarioMinute: 30,
        originalHorarioHour: null,
        originalHorarioMinute: null,
        categoria: "medicacao",
        audioPath: null,
        concluido: false,
        concluidoComFoto: false,
        criadoEm: new Date().toISOString(),
        medicamentoFotoPath: null,
        idosoId: "elderly-a",
        status: "pendente",
        repeteTodosOsDias: true,
        recorrenciaSemanal: false,
        recorrenciaMensal: false,
        recorrenciaIntervalo: false,
        lembreteUnico: false,
        diasSemana: [1, 2, 3, 4, 5, 6, 7],
        diaMes: null,
        intervaloHoras: null,
        recorrencia: "diario",
        dataInicio: "2026-08-22T00:00:00.000",
        dataFim: null,
        isUsoContinuo: true,
        medicamentoInstrucoes: null,
        medicamentoAudioTexto: null,
        prioridade: "normal",
        toleranciaMinutos: 15,
        intervaloRepeticaoMinutos: 5,
        maximoRepeticoes: 3,
        avisarCuidador: true,
        medicamentoDose: "50mg",
        medicamentoUnidade: "comprimido",
        medicamentoEstoque: 30,
        medicamentoEstoqueMinimo: 5,
        medicamentoUnidadesPorDose: 1.0,
        modoConfirmacao: "simples",
        opcoesAdiamentoMinutos: [5, 10, 15],
        maximoAdiamentos: 2,
      };

      await assertSucceeds(
          ownerDb.collection("lembretes").doc(reminderId)
              .set(flutterPayload, {merge: true}),
      );
    });

test("an owner can create voice reminder with single date", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const reminderId = "1787407613305";
  const voicePayload = {
    id: reminderId,
    titulo: "Comprar pão",
    horarioHour: 9,
    horarioMinute: 0,
    originalHorarioHour: null,
    originalHorarioMinute: null,
    categoria: "personalizado",
    audioPath: null,
    concluido: false,
    concluidoComFoto: false,
    criadoEm: new Date().toISOString(),
    medicamentoFotoPath: null,
    idosoId: "elderly-a",
    status: "pendente",
    repeteTodosOsDias: false,
    recorrenciaSemanal: false,
    recorrenciaMensal: false,
    recorrenciaIntervalo: false,
    lembreteUnico: true,
    diasSemana: [],
    diaMes: null,
    intervaloHoras: null,
    recorrencia: "unico",
    dataInicio: "2026-08-22T00:00:00.000",
    dataFim: "2026-08-22T00:00:00.000",
    isUsoContinuo: false,
    medicamentoInstrucoes: null,
    medicamentoAudioTexto: null,
    prioridade: "normal",
    toleranciaMinutos: 15,
    intervaloRepeticaoMinutos: 5,
    maximoRepeticoes: 3,
    avisarCuidador: true,
    medicamentoDose: null,
    medicamentoUnidade: null,
    medicamentoEstoque: null,
    medicamentoEstoqueMinimo: null,
    medicamentoUnidadesPorDose: null,
    modoConfirmacao: "simples",
    opcoesAdiamentoMinutos: [5, 10, 15],
    maximoAdiamentos: 2,
  };

  await assertSucceeds(
      ownerDb.collection("lembretes").doc(reminderId)
          .set(voicePayload, {merge: true}),
  );
});

test(
    "supervisor creates reminder for a migrated canonical profile",
    async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection("idoso_perfil").doc("elderly-legacy").set({
          nome: "Pessoa Legado",
          status: "active",
          supervisorId: "supervisor-legacy",
        });
      });

      const supDb =
        testEnv.authenticatedContext("supervisor-legacy").firestore();
      const reminderId = "1787407613306";
      const payload = {
        id: reminderId,
        titulo: "Tomar Agua",
        horarioHour: 8,
        horarioMinute: 0,
        originalHorarioHour: null,
        originalHorarioMinute: null,
        categoria: "hidratacao",
        audioPath: null,
        concluido: false,
        concluidoComFoto: false,
        criadoEm: new Date().toISOString(),
        medicamentoFotoPath: null,
        idosoId: "elderly-legacy",
        status: "pendente",
        repeteTodosOsDias: true,
        recorrenciaSemanal: false,
        recorrenciaMensal: false,
        recorrenciaIntervalo: false,
        lembreteUnico: false,
        diasSemana: [1, 2, 3, 4, 5, 6, 7],
        diaMes: null,
        intervaloHoras: null,
        recorrencia: "diario",
        dataInicio: "2026-08-22T00:00:00.000",
        dataFim: null,
        isUsoContinuo: true,
        medicamentoInstrucoes: null,
        medicamentoAudioTexto: null,
        prioridade: "normal",
        toleranciaMinutos: 15,
        intervaloRepeticaoMinutos: 5,
        maximoRepeticoes: 3,
        avisarCuidador: true,
        medicamentoDose: null,
        medicamentoUnidade: null,
        medicamentoEstoque: null,
        medicamentoEstoqueMinimo: null,
        medicamentoUnidadesPorDose: null,
        modoConfirmacao: "simples",
        opcoesAdiamentoMinutos: [5, 10, 15],
        maximoAdiamentos: 2,
      };

      await assertSucceeds(
          supDb.collection("lembretes").doc(reminderId)
              .set(payload, {merge: true}),
      );
    });


test("unknown collections remain denied by default", async () => {
  const db = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = db.collection("internal_admin").doc("attempt");
  await assertFails(ref.set({role: "admin"}));
  await assertFails(ref.get());
});

test("supervisor updates reject identity and role spoofing", async () => {
  const db = testEnv.authenticatedContext(
      "supervisor-a",
      {email: "a@example.test"},
  ).firestore();
  const ref = db.collection("supervisores").doc("supervisor-a");

  await assertSucceeds(ref.update({
    nome: "Cuidador A atualizado",
    email: "a@example.test",
    updatedAt: now(),
  }));
  await assertFails(ref.update({email: "victim@example.test"}));
  await assertFails(ref.update({isAdmin: true}));
});

test("reminder queries require an authorized elderly scope", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection("lembretes").doc("query-a")
        .set(validReminder("elderly-a", "query-a"));
    await db.collection("lembretes").doc("query-b")
        .set(validReminder("elderly-b", "query-b"));
  });

  const db = testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      db.collection("lembretes")
          .where("idosoId", "==", "elderly-a")
          .get(),
  );
  await assertFails(db.collection("lembretes").get());
});

test("viewer caregivers cannot mutate or delete messages", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("mensagens").doc("viewer-message")
        .set(validMessage(
            "elderly-a",
            "viewer-message",
            "elderly",
        ));
  });

  const db = testEnv.authenticatedContext("supervisor-viewer").firestore();
  const ref = db.collection("mensagens").doc("viewer-message");
  await assertSucceeds(ref.get());
  await assertFails(ref.update({lido: true}));
  await assertFails(ref.delete());
});

test("caregiver message role must match authenticated identity", async () => {
  const db = testEnv.authenticatedContext("supervisor-a").firestore();
  await assertSucceeds(
      db.collection("mensagens").doc("caregiver-message").set(
          validMessage(
              "elderly-a",
              "caregiver-message",
              "supervisor",
          ),
      ),
  );
  await assertFails(
      db.collection("mensagens").doc("caregiver-forged").set(
          validMessage(
              "elderly-a",
              "caregiver-forged",
              "elderly",
          ),
      ),
  );
});

test("FCM tokens cannot be written for another identity or role", async () => {
  const ownerDb = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = ownerDb.collection("fcm_tokens").doc("elderly_elderly-a");
  await assertSucceeds(ref.set({
    token: "token-elderly-a",
    role: "elderly",
    userId: "elderly-a",
    updatedAt: now(),
  }));
  await assertFails(ref.update({role: "supervisor"}));
  await assertFails(ref.update({userId: "attacker"}));
  await assertFails(ref.update({isAdmin: true}));

  const attackerDb = testEnv.authenticatedContext("attacker").firestore();
  await assertFails(
      attackerDb.collection("fcm_tokens").doc("elderly_elderly-a").set({
        token: "forged-token",
        role: "elderly",
        userId: "elderly-a",
        updatedAt: now(),
      }),
  );
});

test("storage rejects oversized images and disguised file names", async () => {
  const storage = testEnv.authenticatedContext("elderly-a").storage();
  await assertFails(
      storage.ref("reminder_photos/elderly-a/photo.exe").put(
          new Uint8Array([1, 2, 3]),
          {contentType: "image/jpeg"},
      ),
  );
  await assertFails(
      storage.ref("reminder_photos/elderly-a/oversized.jpg").put(
          new Uint8Array(5 * 1024 * 1024 + 1),
          {contentType: "image/jpeg"},
      ),
  );
});

test("video calls enforce participants and status transitions", async () => {
  const elderlyDb = testEnv.authenticatedContext("elderly-a").firestore();
  const ref = elderlyDb.collection("video_calls").doc("call-secure");
  await assertSucceeds(ref.set({
    roomName: "call_secure",
    idosoId: "elderly-a",
    supervisorId: "supervisor-a",
    status: "ringing",
    initiatedBy: "elderly",
    callType: "video",
    startedAt: now(),
  }));

  const attackerDb =
    testEnv.authenticatedContext("supervisor-b").firestore();
  const attackerRef =
    attackerDb.collection("video_calls").doc("call-secure");
  await assertFails(attackerRef.get());
  await assertFails(attackerRef.update({status: "connected"}));
  await assertFails(attackerRef.delete());

  const caregiverDb =
    testEnv.authenticatedContext("supervisor-a").firestore();
  const caregiverRef =
    caregiverDb.collection("video_calls").doc("call-secure");
  await assertSucceeds(caregiverRef.update({status: "connected"}));
  await assertFails(caregiverRef.update({status: "ringing"}));
});

test("caregiver profiles require exact elderly linkage", async () => {
  const linkedDb = testEnv.authenticatedContext("elderly-a").firestore();
  await assertSucceeds(
      linkedDb.collection("supervisores").doc("supervisor-a").get(),
  );

  const otherDb = testEnv.authenticatedContext("elderly-b").firestore();
  await assertFails(
      otherDb.collection("supervisores").doc("supervisor-a").get(),
  );
});
