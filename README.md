# Lembrete Amigo 👵👴🗣️

**Sistema de Apoio à Inclusão Digital de Pessoas Idosas com Baixo Letramento por meio de Lembretes por Voz**

O **Lembrete Amigo** é uma solução móvel multiplataforma desenvolvida em **Flutter** e **Firebase**, criada para proporcionar autonomia na rotina diária de pessoas idosas — especialmente aquelas com baixa visão ou baixo letramento — enquanto permite o acompanhamento remoto por cuidadores e supervisores.

---

## 🚀 Principais Funcionalidades

- **Duplo Perfil (Pessoa Idosa & Supervisor)**:
  - **Pessoa Idosa**: Interface simplificada com botões de alta dimensão (mín. 64px), alto contraste, leitura por voz (Text-to-Speech) e criação por comando de voz (Speech-to-Text).
  - **Supervisor/Cuidador**: Painel administrativo para gestão de lembretes, vinculação via pareamento, acompanhamento de relatórios mensais e gráficos de efetividade.
- **Lembretes por Voz e Mídia**:
  - Reprodução automática em áudio de horários de medicação, alimentação e atividades.
  - Gravação e reprodução de áudios de instrução personalizados.
  - Fotos de medicamentos e confirmação visual.
- **Sincronização Offline & Resiliência**:
  - Suporte a operações sem conexão com internet por meio de fila local (`OfflineSyncService`).
  - Alarmes locais nativos mesmo com a tela desligada.
- **Comunicação & Emergência**:
  - Chamadas de áudio e vídeo integradas (Jitsi Meet).
  - Troca de mensagens de texto, áudio e localização.
  - Botão de emergência / SOS para aviso imediato ao supervisor.

---

## 🛠️ Arquitetura e Tecnologias

- **Frontend**: Flutter / Dart (SDK ^3.10.4)
- **Backend**: Cloud Functions for Firebase (Node.js 22, JavaScript)
- **Banco de Dados**: Cloud Firestore Standard (Modo Nativo)
- **Armazenamento de Mídia**: Cloud Storage for Firebase
- **Autenticação**: Firebase Authentication
- **Notificações**: Firebase Cloud Messaging (FCM) & `flutter_local_notifications`
- **Inteligência Artificial**: Google Gemini API via Cloud Functions

---

## 📋 Pré-requisitos

- Flutter SDK v3.10.4 ou superior
- Dart SDK v3.10.4 ou superior
- Node.js v22 (para as Cloud Functions)
- Firebase CLI (`npx -y firebase-tools@latest`)

---

## 🔧 Configuração e Instalação

1. **Clonar o Repositório**:
   ```bash
   git clone https://github.com/usuario/LembreteAmigo.git
   cd LembreteAmigo
   ```

2. **Instalar Dependências do Flutter**:
   ```bash
   flutter pub get
   ```

3. **Configurar o Firebase**:
   - Inicialize ou vincule o projeto ao Firebase:
     ```bash
     npx -y firebase-tools@latest login
     npx -y firebase-tools@latest use lembreteamigo-26fd0
     ```

4. **Instalar Dependências do Backend**:
   ```bash
   cd functions
   npm install
   cd ..
   ```

---

## 🧪 Execução de Testes

Para executar a suíte completa de testes automatizados unitários e de interface:

```bash
flutter test
```

---

## 📄 Licença e Uso

Este projeto foi desenvolvido como Relatório Técnico de Conclusão de Curso (TCC) no **Instituto Federal do Piauí (IFPI) - Campus Angical do Piauí**.
Todos os direitos reservados.
