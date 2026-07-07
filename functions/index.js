const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

const actionSchema = `
Voce DEVE responder APENAS com um JSON valido nesta estrutura EXATA:

Regra: todo JSON deve ter "emotion" indicando o tom de voz do Alex.
Valores possiveis de emotion:
- "calma": para confortar, acalmar, dar noticias tristes
- "alegre": para parabenizar, comemorar, dar boas noticias
- "informativo": neutro, para listar tarefas, dar instrucoes
- "urgente": para alertas importantes, lembretes atrasados
- "emergencia": situacao de perigo imediato, socorro

Exemplos:

Para EMERGENCIA:
{
  "reply": "Vou pedir socorro agora mesmo.",
  "emotion": "emergencia",
  "action": {"type": "emergency", "confidence": 0.9}
}

Para CONCLUIR lembrete:
{
  "reply": "Muito bem! Ja marquei como feito.",
  "emotion": "alegre",
  "action": {
    "type": "complete_reminder",
    "confidence": 0.8,
    "data": {"reminderTitle": "nome"}
  }
}

Para LISTAR lembretes:
{
  "reply": "Voce tem 3 tarefas hoje...",
  "emotion": "informativo",
  "action": {"type": "list_reminders", "confidence": 0.8}
}

Para CRIAR lembrete:
{
  "reply": "Pronto! Criei o lembrete.",
  "emotion": "informativo",
  "action": {
    "type": "create_reminder",
    "confidence": 0.8,
    "data": {
      "titulo": "...",
      "horarioHour": 8,
      "horarioMinute": 0,
      "categoria": "medicacao",
      "recorrencia": "diario"
    }
  }
}

Para ADIAR lembrete:
{
  "reply": "Tudo bem, vou lembrar mais tarde.",
  "emotion": "informativo",
  "action": {
    "type": "postpone_reminder",
    "confidence": 0.8,
    "data": {"reminderTitle": "nome"}
  }
}

Para SENTIMENTO triste:
{
  "reply": "Sinto muito que voce esta se sentindo assim...",
  "emotion": "calma",
  "action": {
    "type": "sentiment_log",
    "confidence": 0.7,
    "data": {"sentiment": "triste"}
  }
}

Para SENTIMENTO feliz:
{
  "reply": "Que maravilha! Fico muito feliz!",
  "emotion": "alegre",
  "action": {
    "type": "sentiment_log",
    "confidence": 0.7,
    "data": {"sentiment": "feliz"}
  }
}

Para conversa normal / sem acao:
{
  "reply": "resposta em portugues",
  "emotion": "informativo",
  "action": {"type": "general", "confidence": 0}
}

Responda APENAS o JSON, sem texto adicional.
`;

const systemPrompt = `Voce e o Alex, um assistente virtual amigavel e paciente
para um aplicativo de lembretes para idosos brasileiros.

PERSONALIDADE:
- Caloroso, pausado, claro, otimista e paciente
- Use frases curtas e simples (idosos podem ter dificuldade de audicao/atencao)
- Trate o idoso com respeito e carinho, mas sem ser infantil
- Chame o idoso de "voce" (nao "tu" nem "senhor")
- Se o idoso parecer confuso, ofere??a ajuda de forma gentil

CONTEXTO:
O aplicativo gerencia lembretes de:
- Remedios (medicacao): com horarios fixos, foto do remedio, forma e cor
- Atividades: exercicios, caminhada, alongamento
- Alimentacao: cafe da manha, almoco, jantar, lanche
- Bem-estar: check-ins de humor, hidratacao
- Personalizado: qualquer outro lembrete

VOCE PODE:
1. Listar e explicar os lembretes do dia
2. Confirmar quando o idoso completa uma tarefa
3. Ajudar a criar novos lembretes em linguagem natural
4. Oferecer apoio emocional
5. Detectar emergencias (prioridade maxima)
6. Explicar horarios de medicamentos

REGRAS IMPORTANTES:
- Varie sua entonacao (emotion) conforme o contexto:
  alegre ao parabenizar, calma ao confortar,
  informativo ao explicar, urgente em alertas
- Se o idoso parecer confuso ou repetir a mesma pergunta, seja paciente
- Para emergencias, priorize acionar ajuda imediatamente
- Nao invente informacoes sobre medicamentos que nao estao nos lembretes
- Se nao entender, peca para repetir de forma simples`;

exports.alexChat = onCall(
    {cors: true},
    async (request) => {
      const {message, conversationHistory, reminderContext} = request.data;

      if (!message || typeof message !== "string") {
        return {
          reply: "Nao entendi o que voce disse. Pode repetir?",
          emotion: "informativo",
          action: {type: "general", confidence: 0},
        };
      }

      try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({
          model: "gemini-3.5-flash",
          generationConfig: {
            temperature: 0.7,
            topP: 0.9,
            maxOutputTokens: 500,
          },
        });

        let historyForApi = [];
        if (conversationHistory && conversationHistory.length > 0) {
          const sliced = conversationHistory.slice(-10);
          historyForApi = sliced.map((msg) => ({
            role: msg.role === "alex" ? "model" : "user",
            parts: [{text: msg.text}],
          }));
        }

        const chat = model.startChat({
          systemInstruction: {role: "system", parts: [{text: systemPrompt}]},
          history: historyForApi,
        });

        let userMessage = `Mensagem do idoso: ${message}`;
        if (reminderContext && reminderContext.length > 0) {
          userMessage += `\n\nContexto dos lembretes do idoso ` +
+ `(formato JSON):\n${JSON.stringify(reminderContext, null, 2)}`;
        }
        userMessage += `\n\n${actionSchema}`;

        const result = await chat.sendMessage(userMessage);
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
            reply: responseText || "Pode repetir o que voce disse?",
            emotion: "informativo",
            action: {type: "general", confidence: 0},
          };
        }

        return {
          reply: parsed.reply || responseText,
          emotion: parsed.emotion || "informativo",
          action: parsed.action || {type: "general", confidence: 0},
        };
      } catch (error) {
        console.error("Gemini error:", error);
        throw new HttpsError(
            "internal",
            "Erro ao processar sua mensagem.",
        );
      }
    },
);

const supervisorPrompt = `Voce e um assistente de inteligencia artificial
especializado em analisar dados de cuidado de idosos.
Voce ajuda cuidadores e familiares a entenderem a rotina do idoso.

Seu estilo: claro, direto, objetivo, sem rodeios.
Use portugues brasileiro. Seja breve (maximo 3 paragrafos).

Sua funcao e analisar dados de:
- Lembretes (remedios, atividades, refeicoes)
  com status (concluido/pendente/adiado)
- Eventos de conclusao (historico do que foi feito)
- Alertas inteligentes (atrasos, batimentos cardiacos, bem-estar)
- Batimentos cardiacos (BPM)
- Check-ins de bem-estar emocional
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
      const {elderlyData} = request.data;

      if (!elderlyData) {
        return {
          summary: "Sem dados do idoso para analisar.",
          insights: [],
          suggestions: [],
          attentionPoints: [],
        };
      }

      try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({
          model: "gemini-3.5-flash",
          generationConfig: {
            temperature: 0.5,
            topP: 0.9,
            maxOutputTokens: 600,
          },
        });

        const chat = model.startChat({
          systemInstruction: {
            role: "system",
            parts: [{text: supervisorPrompt}],
          },
        });

        const userMessage =
          `Dados do idoso para analisar:\n` +
          `${JSON.stringify(elderlyData, null, 2)}`;

        const result = await chat.sendMessage(userMessage);
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
          summary: parsed.summary || "Resumo nao disponivel.",
          insights: parsed.insights || [],
          suggestions: parsed.suggestions || [],
          attentionPoints: parsed.attentionPoints || [],
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

// --- Video Call Token Generator ------------------------------------------
const {AccessToken} = require("livekit-server-sdk");

exports.generateVideoToken = onCall(
    {cors: true},
    async (request) => {
      const {roomName, identity, metadata} = request.data;

      if (!roomName || !identity) {
        throw new HttpsError(
            "invalid-argument",
            "roomName e identity sao obrigatorios.",
        );
      }

      try {
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
          identity,
          metadata: metadata || "",
          ttl: "6h",
        });

        at.addGrant({
          roomJoin: true,
          room: roomName,
          canPublish: true,
          canSubscribe: true,
        });

        const token = at.toJwt();
        return {token, serverUrl: process.env.LIVEKIT_SERVER_URL || ""};
      } catch (error) {
        console.error("generateVideoToken error:", error);
        throw new HttpsError("internal", "Erro ao gerar token de video.");
      }
    },
);

// --- Medication Identifier (Gemini Vision) --------------------------------
exports.identifyMedication = onCall(
    {cors: true},
    async (request) => {
      const {imageBase64} = request.data;

      if (!imageBase64 || typeof imageBase64 !== "string") {
        return {
          nome: "",
          dosagem: "",
          forma: "",
          cor: "",
          intervaloSugerido: "",
          observacoes: "",
          erro: "Imagem nao fornecida.",
        };
      }

      try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({
          model: "gemini-3.5-flash",
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 300,
          },
        });

        const prompt = `Analise esta imagem de um medicamento.
Responda APENAS com JSON valido, sem texto adicional:
{
  "nome": "nome do medicamento em portugues",
  "dosagem": "ex: 500mg, 10ml, etc",
  "forma": "comprimido|capsula|gotas|pomada",
  "cor": "cor predominante",
  "intervaloSugerido": "8h|12h|24h conforme bula tipica",
  "observacoes": "observacoes relevantes"
}`;

        const imageParts = [
          {text: prompt},
          {
            inlineData: {
              mimeType: "image/jpeg",
              data: imageBase64,
            },
          },
        ];

        const result = await model.generateContent(imageParts);
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
            nome: "",
            dosagem: "",
            forma: "",
            cor: "",
            intervaloSugerido: "",
            observacoes: "",
            erro: "Nao foi possivel interpretar a imagem como um medicamento.",
          };
        }

        return {
          nome: parsed.nome || "",
          dosagem: parsed.dosagem || "",
          forma: parsed.forma || "",
          cor: parsed.cor || "",
          intervaloSugerido: parsed.intervaloSugerido || "",
          observacoes: parsed.observacoes || "",
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

// --- Push Notification ---------------------------------------------------
exports.sendPush = onCall({cors: true, secrets: []}, async (request) => {
  const {targetUserId, targetRole, title, body, data} = request.data;

  if (!targetUserId || !targetRole || !title) {
    throw new HttpsError(
        "invalid-argument",
        "targetUserId, targetRole e title sao obrigatorios.",
    );
  }

  try {
    const docId = `${targetRole}_${targetUserId}`;
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
    const message = {
      token,
      notification: {title, body: body || ""},
      data: data || {},
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
    throw new HttpsError("internal", "Erro ao enviar push notification.");
  }
});
