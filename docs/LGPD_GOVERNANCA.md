# Governança de privacidade e proteção de dados

**Projeto:** Lembrete Amigo  
**Versão da análise:** 25 de agosto de 2026  
**Escopo:** protótipo acadêmico e código-fonte atual

## 1. Objetivo e limite

Este documento registra controles técnicos existentes, categorias de dados e providências necessárias para uma futura operação do Lembrete Amigo. Ele não constitui parecer jurídico nem declaração de conformidade integral com a Lei nº 13.709/2018 (LGPD).

O aplicativo não deve ser disponibilizado como serviço público com dados reais antes da definição formal do controlador, do encarregado ou canal de privacidade, das bases legais, dos prazos de retenção e dos contratos com operadores.

## 2. Papéis a formalizar

- **Titulares:** pessoa idosa, cuidador e demais usuários cadastrados.
- **Controlador:** organização que decidirá finalidades e meios do tratamento; ainda deve ser designada antes da produção.
- **Operadores:** fornecedores de infraestrutura e integrações que tratem dados em nome do controlador.
- **Encarregado/canal do titular:** deve ser publicado no aplicativo e no aviso de privacidade antes da produção.
- **Responsável técnico do protótipo:** autor do projeto, limitado à manutenção acadêmica e técnica.

## 3. Inventário inicial de dados

| Categoria | Exemplos observados no projeto | Finalidade funcional | Sensibilidade |
|---|---|---|---|
| Conta e identificação | UID, nome, e-mail, telefone, papel e vínculo entre idoso e cuidador | autenticação, perfil e autorização | dados pessoais |
| Rotina e saúde | medicamentos, horários, lembretes, eventos de adesão, estoque e métricas informadas | lembretes e acompanhamento | pode incluir dado pessoal sensível de saúde |
| Comunicação e segurança | mensagens, alertas, estado de videochamada e contatos de emergência | comunicação e pedido de ajuda | dados pessoais e conteúdo de comunicação |
| Dispositivo | token de notificação, bateria, modo silencioso e diagnósticos | entrega de alertas e painel do cuidador | dado técnico vinculável ao usuário |
| Voz, imagem e IA | transcrição acionada pelo usuário, foto de embalagem ou receita e perguntas sobre medicamentos | criação assistida de lembretes e explicações | pode conter dado sensível; envio deve ser explícito |
| Telemetria | eventos de uso e relatórios de falha quando habilitados | estabilidade, diagnóstico e melhoria | identificadores técnicos e contexto de erro |

O inventário deve ser revisto a cada nova coleção, campo, integração ou permissão do aplicativo.

## 4. Finalidades e bases legais

As finalidades técnicas estão descritas na tabela anterior. A base legal aplicável depende de quem operar o serviço, do contexto assistencial e da natureza de cada fluxo. Para dados de saúde, a hipótese legal deve ser analisada especificamente à luz dos artigos 7º e 11 da LGPD.

Antes da produção, o controlador deve elaborar um registro de operações de tratamento e validar, para cada finalidade:

1. categoria de titulares e dados;
2. base legal e necessidade;
3. compartilhamentos e transferências internacionais;
4. prazo e critério de retenção;
5. medidas técnicas e administrativas;
6. processo para atender direitos do titular.

Consentimento não deve ser usado como autorização genérica. Quando for a base adequada, precisa ser livre, informado, específico, demonstrável e revogável.

## 5. Serviços e compartilhamentos a avaliar

O código utiliza serviços Firebase para autenticação, banco de dados, armazenamento, funções, notificações, integridade do aplicativo, configuração, análise e falhas. Também possui integrações com Google Generative AI para funções assistidas por IA, Jitsi para videochamadas e recursos do sistema operacional para voz, câmera, localização/configuração do dispositivo e notificações.

Antes da produção, devem ser verificados os termos vigentes, regiões de processamento, suboperadores, transferências internacionais, retenção, treinamento de modelos e mecanismos de exclusão de cada fornecedor. Apenas os dados estritamente necessários devem ser enviados.

## 6. Controles técnicos verificados no repositório

- autenticação antes do acesso aos dados protegidos;
- autorização por identidade, papel e vínculo entre cuidador e idoso;
- negação padrão para coleções não declaradas;
- validação de campos, tipos e transições críticas nas regras do Firestore;
- restrições de proprietário, tamanho e tipo de arquivo no Storage;
- App Check e segredos no lado servidor para reduzir chamadas abusivas e evitar chaves no aplicativo;
- testes automatizados positivos e negativos das regras de Firestore e Storage;
- análise estática, testes Flutter e testes de regras na integração contínua;
- exclusão de arquivos locais de ambiente, segredos e logs pelo arquivo .gitignore.

Esses controles reduzem risco, mas não garantem segurança absoluta. Auditoria independente, monitoramento de produção, gestão de acessos administrativos e resposta a incidentes continuam necessários.

## 7. Retenção e descarte

O protótipo ainda não implementa uma política automática e completa de retenção. Até sua formalização, não se deve afirmar que os dados são apagados em prazo específico.

Para produção, o controlador deve aprovar uma tabela de temporalidade que contemple:

- encerramento da conta e revogação de vínculos;
- lembretes, eventos de adesão e histórico;
- mensagens, chamadas e alertas;
- tokens e diagnósticos de dispositivo;
- arquivos enviados para análise;
- logs de auditoria, segurança e falhas;
- cópias de segurança e prazos de propagação da exclusão.

O princípio orientador é conservar apenas o necessário para a finalidade declarada e eliminar ou anonimizar o restante de forma verificável.

## 8. Atendimento aos direitos do titular

Até que exista automação no aplicativo, o fluxo mínimo deve ser administrativo:

1. receber a solicitação pelo canal oficial publicado;
2. confirmar a identidade sem coletar dados excessivos;
3. registrar protocolo, escopo, data e responsável;
4. localizar dados no Firebase e nos operadores aplicáveis;
5. executar acesso, correção, portabilidade, informação, anonimização, bloqueio ou eliminação conforme a análise jurídica;
6. comunicar a conclusão e registrar evidências;
7. revogar sessões, vínculos e tokens quando houver encerramento.

Solicitações não devem ser atendidas apenas com base em um e-mail não autenticado. O procedimento precisa considerar representante legal e apoio ao idoso sem expor seus dados a terceiros não autorizados.

## 9. Resposta a incidentes

Em caso de suspeita de acesso indevido, perda ou exposição:

1. conter o evento e preservar evidências;
2. revogar credenciais, chaves, sessões ou vínculos afetados;
3. identificar dados, titulares, duração e impacto;
4. corrigir a causa e validar regras e logs;
5. avaliar, com responsáveis jurídico e de segurança, a comunicação à ANPD e aos titulares;
6. registrar decisões, prazos e ações preventivas.

Segredos nunca devem ser incluídos em chamados, capturas de tela ou repositórios públicos.

## 10. Checklist obrigatório antes da produção

- [ ] designar controlador e canal do encarregado/titular;
- [ ] validar bases legais e elaborar registro das operações;
- [ ] publicar aviso de privacidade com dados de contato;
- [ ] aprovar retenção, exclusão e restauração de cópias de segurança;
- [ ] implantar fluxo autenticado de exportação e exclusão;
- [ ] revisar contratos, regiões e configurações dos operadores;
- [ ] executar avaliação de impacto para dados sensíveis e público vulnerável;
- [ ] revisar acessos administrativos e privilégio mínimo;
- [ ] configurar alertas, logs e plano de resposta a incidentes;
- [ ] realizar testes em dispositivos, acessibilidade manual e auditoria de segurança independente;
- [ ] verificar que ambientes de demonstração não contenham dados pessoais reais.

## 11. Revisão

Este documento deve ser revisto antes de cada publicação relevante e sempre que houver nova finalidade, categoria de dados, integração externa, incidente ou alteração normativa.
