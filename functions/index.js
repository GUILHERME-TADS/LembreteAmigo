const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions");
const admin = require("firebase-admin");

setGlobalOptions({maxInstances: 10});

admin.initializeApp();


// =============================================================================
// SECURITY HELPERS
// =============================================================================

/**
 * Validates that request has an authenticated user.
 * @param {Object} request
 * @return {string} The authenticated user's UID.
 */
function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "Usuário não autenticado. Faça login para continuar.",
    );
  }
  return request.auth.uid;
}

/**
 * Validates that a value is a non-empty string with max length.
 * @param {*} value
 * @param {string} name
 * @param {number} maxLength
 * @return {string} Trimmed string.
 */
function validateString(value, name, maxLength = 1000) {
  if (value === null || value === undefined || typeof value !== "string") {
    throw new HttpsError(
        "invalid-argument",
        `${name} é obrigatório e deve ser uma string.`,
    );
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        `${name} não pode estar vazio.`,
    );
  }
  if (trimmed.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${name} excede o limite de ${maxLength} caracteres.`,
    );
  }
  return trimmed;
}

/**
 * Validates a base64 string (minimum size, max 10MB).
 * @param {*} value
 * @param {string} name
 * @return {string} The validated base64 string.
 */
function validateBase64(value, name) {
  if (!value || typeof value !== "string" || value.length < 100) {
    throw new HttpsError(
        "invalid-argument",
        `${name} inválido ou muito pequeno.`,
    );
  }
  if (value.length > 10 * 1024 * 1024) {
    throw new HttpsError(
        "invalid-argument",
        `${name} excede o limite de 10MB.`,
    );
  }
  const cleaned = value.replace(/\s/g, "");
  if (!/^[A-Za-z0-9+/=]+$/.test(cleaned)) {
    throw new HttpsError(
        "invalid-argument",
        `${name} não é um base64 válido.`,
    );
  }
  return cleaned;
}

/**
 * Validates a room name (alphanumeric, hyphens, underscores).
 * @param {*} value
 * @return {string} The validated room name.
 */
function validateRoomName(value) {
  const name = validateString(value, "roomName", 64);
  if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
    throw new HttpsError(
        "invalid-argument",
        "roomName deve conter apenas letras, números, hífens e " +
        "underscores.",
    );
  }
  return name;
}

/**
 * Validates a Firestore document ID.
 * @param {*} value
 * @param {string} name
 * @return {string} The validated ID.
 */
function validateFirestoreId(value, name) {
  const id = validateString(value, name, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
    throw new HttpsError(
        "invalid-argument",
        `${name} contém caracteres inválidos.`,
    );
  }
  return id;
}

/**
 * Checks if an elderly profile is linked to a supervisor.
 * @param {string} elderlyId
 * @param {string} supervisorId
 * @return {Promise<boolean>}
 */
async function isLinkedSupervisor(elderlyId, supervisorId) {
  if (!elderlyId || !supervisorId) return false;
  const doc = await admin.firestore()
      .collection("idoso_perfil")
      .doc(elderlyId)
      .get();
  return doc.exists && doc.data()?.supervisorId === supervisorId;
}

/**
 * Checks whether uid may interact with a target user through the app graph.
 * @param {string} uid
 * @param {string} targetUserId
 * @param {string} targetRole
 * @return {Promise<boolean>}
 */
async function canAccessPushTarget(uid, targetUserId, targetRole) {
  if (uid === targetUserId) return true;
  if (targetRole === "elderly") {
    return isLinkedSupervisor(targetUserId, uid);
  }
  return isLinkedSupervisor(uid, targetUserId);
}

/**
 * Checks whether a video call can be joined by uid in the requested room.
 * @param {string} uid
 * @param {string} callId
 * @param {string} roomName
 * @return {Promise<void>}
 */
async function assertCanJoinVideoCall(uid, callId, roomName) {
  const callDoc = await admin.firestore()
      .collection("video_calls")
      .doc(callId)
      .get();

  if (!callDoc.exists) {
    throw new HttpsError("not-found", "Chamada nao encontrada.");
  }

  const call = callDoc.data() || {};
  if (call.roomName !== roomName) {
    throw new HttpsError("permission-denied", "Sala de chamada invalida.");
  }

  if (!["ringing", "connected"].includes(call.status)) {
    throw new HttpsError(
        "failed-precondition",
        "Esta chamada nao esta mais ativa.",
    );
  }

  if (call.idosoId === uid || call.supervisorId === uid) {
    return;
  }

  if (call.idosoId && await isLinkedSupervisor(call.idosoId, uid)) {
    return;
  }

  throw new HttpsError(
      "permission-denied",
      "Voce nao pode entrar nesta chamada.",
  );
}


// =============================================================================
// RATE LIMITING (Firestore-based token bucket)
// =============================================================================

const RATE_LIMITS = {
  alexChat: {maxCalls: 30, windowMs: 60000},
  supervisorChat: {maxCalls: 20, windowMs: 60000},
  identifyMedication: {maxCalls: 10, windowMs: 60000},
  parsePrescription: {maxCalls: 10, windowMs: 60000},
  parseVoiceReminder: {maxCalls: 20, windowMs: 60000},
  generateVideoToken: {maxCalls: 5, windowMs: 60000},
  sendPush: {maxCalls: 30, windowMs: 60000},
  generateReportInsights: {maxCalls: 5, windowMs: 60000},
  lookupBarcode: {maxCalls: 20, windowMs: 60000},
  analyzeMedication: {maxCalls: 30, windowMs: 60000},
  queryMedicationFAQ: {maxCalls: 30, windowMs: 60000},
};

/**
 * Checks and enforces rate limits for a given function and user.
 * @param {string} uid
 * @param {string} functionName
 */
async function checkRateLimit(uid, functionName) {
  const limit = RATE_LIMITS[functionName];
  if (!limit) return;

  const now = Date.now();
  const docRef = admin.firestore()
      .collection("_rate_limits")
      .doc(`${functionName}_${uid}`);

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      const data = doc.data();

      if (!data || now - data.windowStart > limit.windowMs) {
        transaction.set(docRef, {
          count: 1,
          windowStart: now,
          functionName,
          uid,
        });
        return;
      }

      if (data.count >= limit.maxCalls) {
        const retryAfterMs = limit.windowMs - (now - data.windowStart);
        throw new HttpsError(
            "resource-exhausted",
            `Muitas requisições. Aguarde ` +
            `${Math.ceil(retryAfterMs / 1000)} segundos.`,
        );
      }

      transaction.update(
          docRef,
          {count: admin.firestore.FieldValue.increment(1)},
      );
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error(`Rate limit check error for ${functionName}:`, error);
  }
}


// =============================================================================
// GEMINI HELPER
// =============================================================================

/**
 * Creates a Gemini model instance with the given config.
 * @param {string} modelName
 * @param {Object} config
 * @return {Object} Gemini model instance.
 */
function createGeminiModel(modelName, config) {
  const {GoogleGenerativeAI} = require("@google/generative-ai");
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError(
        "failed-precondition",
        "Gemini API não configurada.",
    );
  }
  const genAI = new GoogleGenerativeAI(apiKey);
  return genAI.getGenerativeModel({
    model: modelName || "gemini-2.5-flash",
    ...config,
  });
}

/**
 * Appends the standard medical disclaimer when it is not already present.
 * @param {string} text
 * @return {string} Text with the medical disclaimer.
 */
function appendMedicalDisclaimer(text) {
  const disclaimer =
    " Esta orientacao e apenas informativa e nao substitui a avaliacao de " +
    "um medico ou farmaceutico. Em caso de duvida, reacao adversa ou " +
    "interacao importante, procure um profissional de saude.";
  const safeText = String(text || "").trim();
  if (!safeText) return disclaimer.trim();
  if (safeText.toLowerCase().includes("nao substitui")) return safeText;
  return `${safeText}${disclaimer}`;
}


// =============================================================================
// ALEX CHAT (Elderly Assistant)
// =============================================================================

exports.alexChat = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "alexChat");

      validateString(request.data?.message, "message", 2000);

      return {
        reply: "Desculpe, ainda nao sei responder a essa pergunta.",
        emotion: "informativo",
        action: {type: "general", confidence: 0},
      };
    },
);


// =============================================================================
// SUPERVISOR CHAT (Daily Summary)
// =============================================================================

const supervisorPrompt = `Voce e um assistente de inteligencia artificial
especializado em analisar dados de cuidado de idosos.
Voce ajuda cuidadores e familiares a entenderem a rotina do idoso.

Seu estilo: claro, direto, objetivo, sem rodeios.
Use portugues brasileiro. Seja breve (maximo 3 paragrafos).

Sua funcao e analisar dados de:
- Lembretes (remedios, atividades, refeicoes)
  com status (concluido/pendente/adiado)
- Eventos de conclusao (historico do que foi feito)
- Alertas inteligentes (atrasos)
- Status do dispositivo (bateria, volume, online)

Sempre responda APENAS com JSON valido:
{
  "summary": "Resumo do dia do idoso em 2-3 frases",
  "insights": [
    "Insight 1 sobre padrao observado",
    "Insight 2 sobre algo relevante"
  ],
  "suggestions": [
    "Sugestao 1 para o cuidador",
    "Sugestao 2 para o cuidador"
  ],
  "attentionPoints": [
    "Ponto de atencao 1 (se houver)"
  ]
}

Regras:
- Nao invente dados. Baseie-se apenas nos dados fornecidos.
- Se nao houver dados suficientes, informe educadamente.
- insights e suggestions podem ser listas vazias se nada relevante.
- attentionPoints pode ser vazio se tudo normal.
- Seja empatico com o idoso e util para o cuidador.`;

exports.supervisorChat = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "supervisorChat");

      const {elderlyData} = request.data;

      if (!elderlyData || typeof elderlyData !== "object") {
        return {
          summary: "Sem dados do idoso para analisar.",
          insights: [],
          suggestions: [],
          attentionPoints: [],
        };
      }

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.5,
            topP: 0.9,
            maxOutputTokens: 2048,
          },
        });

        const serialized =
            JSON.stringify(elderlyData, null, 2).slice(0, 50000);

        const chat = model.startChat({
          systemInstruction: {
            role: "system",
            parts: [{text: supervisorPrompt}],
          },
        });

        const result = await chat.sendMessage(
            `Dados do idoso para analisar:\n${serialized}`,
        );
        const responseText = result.response.text();

        const cleaned = responseText
            .replace(/```json\s*/gi, "")
            .replace(/```\s*$/g, "")
            .replace(/```/g, "")
            .trim();

        let parsed;
        try {
          parsed = JSON.parse(cleaned);
        } catch (e) {
          return {
            summary: responseText ||
              "Nao foi possivel gerar resumo agora.",
            insights: [],
            suggestions: [],
            attentionPoints: [],
          };
        }

        return {
          summary: String(parsed.summary || "Resumo nao disponivel.")
              .slice(0, 2000),
          insights: Array.isArray(parsed.insights) ?
              parsed.insights.slice(0, 10).map(String) : [],
          suggestions: Array.isArray(parsed.suggestions) ?
              parsed.suggestions.slice(0, 10).map(String) : [],
          attentionPoints: Array.isArray(parsed.attentionPoints) ?
              parsed.attentionPoints.slice(0, 10).map(String) : [],
        };
      } catch (error) {
        console.error("supervisorChat error:", error);
        throw new HttpsError(
            "internal",
            "Erro ao analisar dados do idoso.",
        );
      }
    },
);


// =============================================================================
// REPORT INSIGHTS GENERATOR
// =============================================================================

const reportPrompt =
    "Voce e um especialista em geriatria e analise de saude digital.\n" +
    "Analise os dados semanais de saude e rotina de um idoso fornecidos " +
    "no input e gere duas analises clinicas em portugues brasileiro:\n" +
    "1. resumoFamiliar: Um paragrafo curto (ate 3 frases) focado nos " +
    "familiares, explicando de forma empatica como foi a rotina do idoso " +
    "esta semana, destacando os pontos fortes e observando a " +
    "estabilidade.\n" +
    "2. pontoAtencao: Um paragrafo curto clinico, indicando fatores a " +
    "serem monitorados ou sugestoes praticas para o cuidador caso haja " +
    "atividades perdidas. Se tudo estiver normal, indique que a rotina " +
    "segue estavel.";

const reportSchema = {
  type: "object",
  properties: {
    resumoFamiliar: {
      type: "string",
      description: "Resumo amigavel para a familia do idoso.",
    },
    pontoAtencao: {
      type: "string",
      description: "Recomendacao ou alerta clinico para o cuidador.",
    },
  },
  required: ["resumoFamiliar", "pontoAtencao"],
};

exports.generateReportInsights = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "generateReportInsights");

      const data = request.data;

      const idosoName = data && typeof data.idosoName === "string" ?
          data.idosoName.trim().slice(0, 100) : "Idoso";

      const adesaoGeral = typeof data.adesaoGeral === "number" ?
          Math.min(100, Math.max(0, data.adesaoGeral)) : 0;
      const totalAtividades = typeof data.totalAtividades === "number" ?
          Math.max(0, Math.min(1000, data.totalAtividades)) : 0;
      const concluidas = typeof data.concluidas === "number" ?
          Math.max(0, Math.min(1000, data.concluidas)) : 0;
      const naoFeitas = typeof data.naoFeitas === "number" ?
          Math.max(0, Math.min(1000, data.naoFeitas)) : 0;
      const medicacaoPct = typeof data.medicacaoPct === "number" ?
          Math.min(100, Math.max(0, data.medicacaoPct)) : 0;
      const refeicoesPct = typeof data.refeicoesPct === "number" ?
          Math.min(100, Math.max(0, data.refeicoesPct)) : 0;
      const exercicioPct = typeof data.exercicioPct === "number" ?
          Math.min(100, Math.max(0, data.exercicioPct)) : 0;
      const hidratacaoPct = typeof data.hidratacaoPct === "number" ?
          Math.min(100, Math.max(0, data.hidratacaoPct)) : 0;

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
            responseSchema: reportSchema,
          },
        });

        const context =
            `Idoso: ${idosoName}\n` +
            `Adesao Geral: ${adesaoGeral}%\n` +
            `Total de Lembretes: ${totalAtividades}\n` +
            `Concluidos: ${concluidas}\n` +
            `Nao Feitos: ${naoFeitas}\n` +
            `Adesao Medicamento: ${medicacaoPct}%\n` +
            `Adesao Refeicoes: ${refeicoesPct}%\n` +
            `Adesao Exercicios: ${exercicioPct}%\n` +
            `Adesao Hidratacao: ${hidratacaoPct}%\n`;

        const result = await model.generateContent([
          {text: reportPrompt},
          {text: `Dados do paciente:\n${context}`},
        ]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error(
              "Erro ao analisar JSON de relatorio:", e, responseText,
          );
          return {
            resumoFamiliar: "Falha ao gerar resumo da semana com IA.",
            pontoAtencao: "Falha ao gerar ponto de atencao com IA.",
          };
        }

        return {
          resumoFamiliar:
              String(parsed.resumoFamiliar || "").slice(0, 2000),
          pontoAtencao:
              String(parsed.pontoAtencao || "").slice(0, 2000),
        };
      } catch (error) {
        console.error("generateReportInsights error:", error);
        return {
          resumoFamiliar:
              "Nao foi possivel carregar o resumo semanal com IA.",
          pontoAtencao:
              "Nao foi possivel carregar o ponto de atencao com IA.",
        };
      }
    },
);


// =============================================================================
// VIDEO CALL TOKEN GENERATOR
// =============================================================================

exports.generateVideoToken = onCall(
    {cors: true},
    async (request) => {
      const {AccessToken} = require("livekit-server-sdk");
      const uid = requireAuth(request);
      await checkRateLimit(uid, "generateVideoToken");

      const {callId, roomName, identity, metadata} = request.data;

      const validatedCallId = validateFirestoreId(callId, "callId");
      const validatedRoom = validateRoomName(roomName);
      const validatedIdentity =
          validateFirestoreId(identity, "identity");

      if (uid !== validatedIdentity) {
        throw new HttpsError(
            "permission-denied",
            "Você só pode gerar token para sua própria identidade.",
        );
      }

      try {
        await assertCanJoinVideoCall(uid, validatedCallId, validatedRoom);

        const apiKey = process.env.LIVEKIT_API_KEY;
        const apiSecret = process.env.LIVEKIT_API_SECRET;

        if (!apiKey || !apiSecret) {
          throw new HttpsError(
              "failed-precondition",
              "LiveKit nao configurado. " +
              "Defina LIVEKIT_API_KEY e LIVEKIT_API_SECRET.",
          );
        }

        const at = new AccessToken(apiKey, apiSecret, {
          identity: validatedIdentity,
          metadata: typeof metadata === "string" ?
              metadata.slice(0, 500) : "",
          ttl: "6h",
        });

        at.addGrant({
          roomJoin: true,
          room: validatedRoom,
          canPublish: true,
          canSubscribe: true,
        });

        const token = at.toJwt();
        return {
          token,
          serverUrl: process.env.LIVEKIT_SERVER_URL || "",
          identity: validatedIdentity,
          room: validatedRoom,
        };
      } catch (error) {
        console.error("generateVideoToken error:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", "Erro ao gerar token de video.");
      }
    },
);


// =============================================================================
// MEDICATION IDENTIFIER (Gemini Vision)
// =============================================================================

exports.identifyMedication = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "identifyMedication");

      const {imageBase64} = request.data;
      const validatedImage = validateBase64(imageBase64, "imageBase64");

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: {
                nome: {type: "string"},
                dosagem: {type: "string"},
                forma: {type: "string"},
                cor: {type: "string"},
                intervaloSugerido: {type: "string"},
                observacoes: {type: "string"},
              },
              required: [
                "nome",
                "dosagem",
                "forma",
                "cor",
                "intervaloSugerido",
                "observacoes",
              ],
            },
          },
        });

        const prompt =
          "Analise esta imagem de um medicamento e extraia " +
          "as informações correspondentes.";

        const imageParts = [
          {text: prompt},
          {
            inlineData: {
              mimeType: "image/jpeg",
              data: validatedImage,
            },
          },
        ];

        const result = await model.generateContent(imageParts);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error(
              "Erro ao analisar JSON retornado:",
              e,
              "Resposta original:",
              responseText,
          );
          return {
            nome: "",
            dosagem: "",
            forma: "",
            cor: "",
            intervaloSugerido: "",
            observacoes: "",
            erro: "Nao foi possivel interpretar a imagem " +
                  "como um medicamento.",
          };
        }

        return {
          nome: String(parsed.nome || "").slice(0, 200),
          dosagem: String(parsed.dosagem || "").slice(0, 100),
          forma: String(parsed.forma || "").slice(0, 100),
          cor: String(parsed.cor || "").slice(0, 100),
          intervaloSugerido:
              String(parsed.intervaloSugerido || "").slice(0, 500),
          observacoes:
              String(parsed.observacoes || "").slice(0, 1000),
          erro: "",
        };
      } catch (error) {
        console.error("identifyMedication error:", error);
        return {
          nome: "",
          dosagem: "",
          forma: "",
          cor: "",
          intervaloSugerido: "",
          observacoes: "",
          erro: "Erro ao identificar medicamento. Tente novamente.",
        };
      }
    },
);


// =============================================================================
// PRESCRIPTION PARSER (Gemini Vision)
// =============================================================================

const prescriptionPrompt =
    "Analise esta imagem de uma receita medica. Extraia todos os " +
    "medicamentos listados, interpretando a posologia e determinando o " +
    "horario de agendamento inicial correto para cada lembrete de " +
    "medicao.\n" +
    "Se a receita descrever multiplas doses (ex: de 8 em 8 horas), " +
    "crie apenas o lembrete para a primeira dose do dia, e indique " +
    "o intervalo nas observacoes.";

const prescriptionSchema = {
  type: "object",
  properties: {
    lembretes: {
      type: "array",
      items: {
        type: "object",
        properties: {
          titulo: {
            type: "string",
            description: "Nome do medicamento",
          },
          horarioHour: {
            type: "integer",
            description: "Hora da primeira dose",
          },
          horarioMinute: {
            type: "integer",
            description: "Minuto da primeira dose",
          },
          categoria: {type: "string", enum: ["medicacao"]},
          observacoes: {
            type: "string",
            description: "Frequencia, duracao ou posologia descrita",
          },
          dosagem: {
            type: "string",
            description: "Dosagem ex: 50mg, 1 comprimido, 20 gotas",
          },
        },
        required: [
          "titulo",
          "horarioHour",
          "horarioMinute",
          "categoria",
          "observacoes",
          "dosagem",
        ],
      },
    },
  },
  required: ["lembretes"],
};

exports.parsePrescription = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "parsePrescription");

      const {imageBase64} = request.data;
      const validatedImage = validateBase64(imageBase64, "imageBase64");

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.15,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: prescriptionSchema,
          },
        });

        const imageParts = [
          {text: "Analise esta receita medica:"},
          {
            inlineData: {
              mimeType: "image/jpeg",
              data: validatedImage,
            },
          },
        ];

        const result = await model.generateContent([
          {text: prescriptionPrompt},
          ...imageParts,
        ]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error(
              "Erro ao analisar JSON de receita:", e, responseText,
          );
          return {
            lembretes: [],
            erro: "Nao foi possivel estruturar os dados da receita.",
          };
        }

        const sanitizedLembretes = (parsed.lembretes || [])
            .slice(0, 20)
            .map((l) => ({
              titulo: String(l.titulo || "").slice(0, 200),
              horarioHour: typeof l.horarioHour === "number" ?
                  Math.min(23, Math.max(0, l.horarioHour)) : 0,
              horarioMinute: typeof l.horarioMinute === "number" ?
                  Math.min(59, Math.max(0, l.horarioMinute)) : 0,
              categoria: "medicacao",
              observacoes: String(l.observacoes || "").slice(0, 500),
              dosagem: String(l.dosagem || "").slice(0, 100),
            }));

        return {
          lembretes: sanitizedLembretes,
          erro: "",
        };
      } catch (error) {
        console.error("parsePrescription error:", error);
        return {
          lembretes: [],
          erro: "Erro ao processar receita medica. Tente novamente.",
        };
      }
    },
);


// =============================================================================
// VOICE REMINDER PARSER
// =============================================================================

const voiceReminderPrompt =
    "Voce e um assistente especializado em extrair lembretes a partir " +
    "de transcricoes de fala em portugues brasileiro.\n" +
    "Analise a transcricao fornecida e identifique o titulo do lembrete, " +
    "o horario (hora e minuto) e a categoria correspondente.\n\n" +
    "Categorias disponiveis:\n" +
    "- \"medicacao\": para remedios, comprimidos, injecoes, colirios, " +
    "etc.\n" +
    "- \"refeicoes\": para cafe da manha, almoco, jantar, lanche, " +
    "comer, etc.\n" +
    "- \"exercicio\": para caminhada, alongamento, ginastica, " +
    "pilates, etc.\n" +
    "- \"hidratacao\": para beber agua, hidratacao, etc.\n" +
    "- \"personalizado\": qualquer outro tipo de tarefa.\n\n" +
    "Regras importantes:\n" +
    "1. Extraia o horario. Se nao for mencionado nenhum horario ou " +
    "periodo que permita deduzir o horario, retorne \"sucesso\": false.\n" +
    "2. Limpe o titulo: remova preposicoes de tempo (como \"as\", " +
    "\"as X horas\", \"da manha\", \"da noite\", \"da tarde\") e " +
    "verbos auxiliares de forma que o titulo fique direto e claro " +
    "(ex: de \"lembrar de tomar o remedio\" para \"Tomar o remedio\").\n" +
    "3. Detecte periodos: se disser \"tarde\" ou \"noite\", ajuste a " +
    "hora para o formato 24h (ex: \"8 da noite\" -> hora: 20, " +
    "minuto: 0; \"meio-dia\" -> hora: 12, minuto: 0; " +
    "\"meia-noite\" -> hora: 0, minuto: 0).\n" +
    "4. Retorne \"sucesso\": true apenas se conseguir identificar " +
    "o titulo (mesmo que simplificado) e um horario.";

exports.parseVoiceReminder = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "parseVoiceReminder");

      const {text} = request.data;
      const validatedText = validateString(text, "text", 2000);

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: {
                titulo: {type: "string"},
                horarioHour: {type: "integer"},
                horarioMinute: {type: "integer"},
                categoria: {
                  type: "string",
                  enum: [
                    "medicacao",
                    "refeicoes",
                    "exercicio",
                    "hidratacao",
                    "personalizado",
                  ],
                },
                sucesso: {type: "boolean"},
              },
              required: [
                "titulo",
                "horarioHour",
                "horarioMinute",
                "categoria",
                "sucesso",
              ],
            },
          },
        });

        const result = await model.generateContent([
          {text: voiceReminderPrompt},
          {text: `Analise a transcricao a seguir:\n"${validatedText}"`},
        ]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error(
              "Erro ao analisar JSON retornado:",
              e,
              "Resposta:",
              responseText,
          );
          return {
            titulo: "",
            horarioHour: 0,
            horarioMinute: 0,
            categoria: "personalizado",
            sucesso: false,
            erro: "Falha ao processar resposta do modelo.",
          };
        }

        return {
          titulo: String(parsed.titulo || "").slice(0, 200),
          horarioHour: typeof parsed.horarioHour === "number" ?
              Math.min(23, Math.max(0, parsed.horarioHour)) : 0,
          horarioMinute: typeof parsed.horarioMinute === "number" ?
              Math.min(59, Math.max(0, parsed.horarioMinute)) : 0,
          categoria: parsed.categoria || "personalizado",
          sucesso: !!parsed.sucesso,
          erro: "",
        };
      } catch (error) {
        console.error("parseVoiceReminder error:", error);
        return {
          titulo: "",
          horarioHour: 0,
          horarioMinute: 0,
          categoria: "personalizado",
          sucesso: false,
          erro: "Erro ao processar voz com o assistente.",
        };
      }
    },
);


// =============================================================================
// PUSH NOTIFICATION
// =============================================================================

exports.sendPush = onCall({cors: true, secrets: []}, async (request) => {
  const uid = requireAuth(request);
  await checkRateLimit(uid, "sendPush");

  const {targetUserId, targetRole, title, body, data} = request.data;

  const validatedTargetUserId =
      validateFirestoreId(targetUserId, "targetUserId");
  const validatedTitle = validateString(title, "title", 200);

  const validRoles = ["elderly", "supervisor"];
  const validatedRole = String(targetRole || "").trim().toLowerCase();
  if (!validRoles.includes(validatedRole)) {
    throw new HttpsError(
        "invalid-argument",
        "targetRole deve ser 'elderly' ou 'supervisor'.",
    );
  }

  try {
    const canSend = await canAccessPushTarget(
        uid,
        validatedTargetUserId,
        validatedRole,
    );
    if (!canSend) {
      throw new HttpsError(
          "permission-denied",
          "Voce nao pode enviar notificacao para este usuario.",
      );
    }

    const docId = `${validatedRole}_${validatedTargetUserId}`;
    const tokenDoc = await admin.firestore()
        .collection("fcm_tokens")
        .doc(docId)
        .get();

    if (!tokenDoc.exists) {
      return {success: false, reason: "token_nao_encontrado"};
    }
    const tokenData = tokenDoc.data();
    if (!tokenData || !tokenData.token) {
      return {success: false, reason: "token_nao_encontrado"};
    }

    const token = tokenData.token;
    const validatedBody = body && typeof body === "string" ?
        body.slice(0, 500) : "";
    const validatedData = data && typeof data === "object" ?
        Object.fromEntries(
            Object.entries(data)
                .slice(0, 10)
                .map(([k, v]) => [
                  String(k).slice(0, 50),
                  String(v).slice(0, 500),
                ]),
        ) : {};

    const message = {
      token,
      notification: {title: validatedTitle, body: validatedBody},
      data: validatedData,
      android: {priority: "high"},
      apns: {
        payload: {
          aps: {
            "sound": "default",
            "badge": 1,
            "content-available": 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    return {success: true, messageId: response};
  } catch (error) {
    console.error("sendPush error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "Erro ao enviar push notification.");
  }
});

// =============================================================================
// BARCODE LOOKUP
// =============================================================================

const BARCODE_SCHEMA = {
  type: "object",
  properties: {
    nome: {type: "string"},
    dosagem: {type: "string"},
    forma: {type: "string"},
    cor: {type: "string"},
  },
  required: ["nome", "dosagem", "forma", "cor"],
};

exports.lookupBarcode = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "lookupBarcode");

      const {barcode} = request.data;
      if (!barcode ||
          typeof barcode !== "string" ||
          barcode.trim().length === 0) {
        return {
          nome: "", dosagem: "", forma: "", cor: "",
          erro: "Código de barras inválido.",
        };
      }

      const cleanBarcode = barcode.trim();

      // 1. Try Firestore cache first
      try {
        const cached = await admin.firestore()
            .collection("medicamentos_barcode")
            .doc(cleanBarcode)
            .get();
        if (cached.exists) {
          const data = cached.data();
          return {
            nome: String(data.nome || "").slice(0, 200),
            dosagem: String(data.dosagem || "").slice(0, 100),
            forma: String(data.forma || "").slice(0, 100),
            cor: String(data.cor || "").slice(0, 100),
            erro: "",
          };
        }
      } catch (e) {
        console.error("Firestore lookup error:", e);
      }

      // 2. Try Gemini to identify by barcode using Google Search grounding
      try {
        const searchModel = createGeminiModel("gemini-2.5-flash", {
          tools: [{googleSearch: {}}],
        });

        const searchPrompt =
          "Pesquise na internet qual é o produto ou " +
          "medicamento brasileiro correspondente ao " +
          "código de barras EAN-13 '" + cleanBarcode + "'. " +
          "Retorne detalhes como nome do produto, " +
          "dosagem/peso, forma de uso e cor da embalagem.";

        const searchResult =
            await searchModel.generateContent([{text: searchPrompt}]);
        const searchText = searchResult.response.text();

        const parserModel = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.1,
            responseMimeType: "application/json",
            responseSchema: BARCODE_SCHEMA,
          },
        });

        const parsePrompt =
          "Extraia as informações do seguinte texto sobre o " +
          "produto do código de barras " + cleanBarcode + ":\n\n" +
          searchText + "\n\n" +
          "Responda em JSON seguindo o esquema definido.";

        const result = await parserModel.generateContent([{text: parsePrompt}]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error(
              "Erro ao analisar JSON de barcode:", e,
              "Resposta:", responseText,
          );
          return {
            nome: "", dosagem: "", forma: "", cor: "",
            erro: "Código de barras não reconhecido.",
          };
        }

        const nome = String(parsed.nome || "").trim();
        if (!nome) {
          return {
            nome: "", dosagem: "", forma: "", cor: "",
            erro: "Medicamento não encontrado para este código de barras.",
          };
        }

        const dosagem = String(parsed.dosagem || "").trim();
        const forma = String(parsed.forma || "").trim();
        const cor = String(parsed.cor || "").trim();

        // Cache in Firestore for future lookups
        try {
          await admin.firestore()
              .collection("medicamentos_barcode")
              .doc(cleanBarcode)
              .set({
                nome,
                dosagem,
                forma,
                cor,
                consultadoEm: admin.firestore.FieldValue.serverTimestamp(),
                consultadoPor: uid,
              });
        } catch (e) {
          console.error("Erro ao salvar cache de barcode:", e);
        }

        return {
          nome: nome.slice(0, 200),
          dosagem: dosagem.slice(0, 100),
          forma: forma.slice(0, 100),
          cor: cor.slice(0, 100),
          erro: "",
        };
      } catch (error) {
        console.error("lookupBarcode error:", error);
        return {
          nome: "", dosagem: "", forma: "", cor: "",
          erro: "Erro ao consultar código de barras.",
        };
      }
    },
);

const ANALYSIS_SCHEMA = {
  type: "object",
  properties: {
    guidelines: {type: "string"},
    suggestedAudioText: {type: "string"},
    hasInteraction: {type: "boolean"},
    severity: {type: "string"},
    interactionWarning: {type: "string"},
    schedulingConflictWarning: {type: "string"},
  },
  required: [
    "guidelines",
    "suggestedAudioText",
    "hasInteraction",
    "severity",
    "interactionWarning",
    "schedulingConflictWarning",
  ],
};

exports.analyzeMedication = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "analyzeMedication");

      const {
        newMedication,
        newMedicationTime,
        existingMedications,
      } = request.data;

      if (!newMedication) {
        return {
          guidelines: "",
          suggestedAudioText: "",
          hasInteraction: false,
          severity: "none",
          interactionWarning: "",
          schedulingConflictWarning: "",
        };
      }

      const cleanNew = String(newMedication).trim().slice(0, 200);
      const cleanTime = String(newMedicationTime || "").trim().slice(0, 10);
      const cleanExisting = Array.isArray(existingMedications) ?
          existingMedications.slice(0, 30).map((m) => ({
            titulo: String(m.titulo || "").trim().slice(0, 200),
            horario: String(m.horario || "").trim().slice(0, 10),
          })).filter((m) => m.titulo.length > 0) : [];

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json",
            responseSchema: ANALYSIS_SCHEMA,
          },
        });

        let prompt =
          "Você é um farmacologista clínico especializado em geriatria " +
          "brasileira.\n" +
          "Analise o novo medicamento '" + cleanNew + "' agendado para às " +
          cleanTime + ".\n\n";

        if (cleanExisting.length > 0) {
          prompt += "O paciente já toma os seguintes medicamentos:\n" +
            cleanExisting.map((e) => `- ${e.titulo} às ${e.horario}`)
                .join("\n") + "\n\n";
        } else {
          prompt += "O paciente não toma outros medicamentos cadastrados " +
            "no momento.\n\n";
        }

        prompt +=
          "Por favor, realize a seguinte análise clínica e preencha o " +
          "JSON de resposta:\n" +
          "1. 'guidelines': Forneça instruções de administração curtas e " +
          "diretas em português (ex: 'Tomar em jejum com água', 'Não tomar " +
          "com leite').\n" +
          "2. 'suggestedAudioText': Crie uma fala curta e acolhedora em " +
          "português voltada para o idoso tomar o remédio (ex: 'Olá! Está " +
          "na hora de tomar seu Paracetamol. Beba um copo de água.').\n" +
          "3. 'hasInteraction' e 'severity' ('none', 'moderate', 'severe') " +
          "e 'interactionWarning': Analise se há interações graves ou " +
          "moderadas entre o novo medicamento e os existentes.\n" +
          "4. 'schedulingConflictWarning': Analise se agendar o novo " +
          "medicamento às " + cleanTime + " causa polimedicação excessiva " +
          "(ex: mais de 3 medicamentos no mesmo horário) ou se há " +
          "interações/recomendações sobre tomar esses remédios juntos " +
          "na mesma hora, sugerindo espaçamento de horários se " +
          "necessário (caso contrário, deixe em branco).";

        const result = await model.generateContent([{text: prompt}]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error("Erro ao analisar JSON de analise:", e);
          return {
            guidelines: "",
            suggestedAudioText: "",
            hasInteraction: false,
            severity: "none",
            interactionWarning: "",
            schedulingConflictWarning: "",
          };
        }

        const audioTxt = String(parsed.suggestedAudioText || "")
            .slice(0, 1000);
        const interactWarn = String(parsed.interactionWarning || "")
            .slice(0, 1000);

        return {
          guidelines: appendMedicalDisclaimer(parsed.guidelines).slice(0, 900),
          suggestedAudioText: appendMedicalDisclaimer(audioTxt).slice(0, 1400),
          hasInteraction: !!parsed.hasInteraction,
          severity: String(parsed.severity || "none").slice(0, 50),
          interactionWarning: parsed.hasInteraction ?
              appendMedicalDisclaimer(interactWarn).slice(0, 1400) :
              interactWarn,
          schedulingConflictWarning:
              parsed.schedulingConflictWarning ?
                  appendMedicalDisclaimer(parsed.schedulingConflictWarning)
                      .slice(0, 1400) :
                  "",
        };
      } catch (error) {
        console.error("analyzeMedication error:", error);
        return {
          guidelines: "",
          suggestedAudioText: "",
          hasInteraction: false,
          severity: "none",
          interactionWarning: "",
          schedulingConflictWarning: "",
        };
      }
    },
);

const FAQ_SCHEMA = {
  type: "object",
  properties: {
    answer: {type: "string"},
  },
  required: ["answer"],
};

exports.queryMedicationFAQ = onCall(
    {cors: true},
    async (request) => {
      const uid = requireAuth(request);
      await checkRateLimit(uid, "queryMedicationFAQ");

      const {medicationName, question} = request.data;
      if (!medicationName || !question) {
        return {answer: "Nome do remédio e pergunta são obrigatórios."};
      }

      const cleanName = String(medicationName).trim().slice(0, 200);
      const cleanQuestion = String(question).trim().slice(0, 500);

      try {
        const model = createGeminiModel("gemini-2.5-flash", {
          generationConfig: {
            temperature: 0.3,
            responseMimeType: "application/json",
            responseSchema: FAQ_SCHEMA,
          },
        });

        const prompt =
          "Você é um farmacêutico clínico especialista em bulas de " +
          "medicamentos do mercado brasileiro.\n" +
          "Responda à seguinte dúvida sobre o medicamento '" + cleanName +
          "':\n" +
          "Dúvida: '" + cleanQuestion + "'\n\n" +
          "Instruções:\n" +
          "1. Forneça uma resposta precisa, segura, acolhedora e baseada na " +
          "bula oficial do medicamento.\n" +
          "2. Seja claro e direto, ideal para leigos e cuidadores.\n" +
          "3. Sempre adicione um aviso ao final de que a resposta não " +
          "substitui a consulta ao médico ou farmacêutico.";

        const result = await model.generateContent([{text: prompt}]);
        const responseText = result.response.text();

        let parsed;
        try {
          parsed = JSON.parse(responseText.trim());
        } catch (e) {
          console.error("Erro ao analisar JSON de FAQ:", e);
          return {answer: "Não foi possível obter a resposta no momento."};
        }

        return {
          answer: appendMedicalDisclaimer(parsed.answer).slice(0, 2400),
        };
      } catch (error) {
        console.error("queryMedicationFAQ error:", error);
        return {answer: "Erro ao consultar a bula digital."};
      }
    },
);
