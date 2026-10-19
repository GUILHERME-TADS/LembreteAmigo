# Auditoria de acessibilidade — Lembrete Amigo

**Data:** 25 de agosto de 2026  
**Escopo:** código Flutter e testes automatizados do protótipo

## Resultado

A análise estática foi concluída sem problemas e a suíte Flutter executou 163 de 163 testes com sucesso. Quatro testes específicos foram adicionados para os controles essenciais destinados ao público idoso.

Este resultado comprova os itens automatizados descritos abaixo. Ele não representa certificação de conformidade integral com WCAG nem substitui avaliação humana com pessoas idosas e tecnologias assistivas.

## Controles verificados automaticamente

| Controle | Evidência automatizada | Resultado |
|---|---|---|
| Rótulo do botão principal | nó semântico localizável pelo nome da ação | aprovado |
| Área tátil do botão principal | altura mínima igual ou superior a 48 pixels lógicos | aprovado |
| Botão de emergência | rótulo e dica “pressione e segure” expostos à árvore semântica | aprovado |
| Confirmação prolongada | rótulo e instrução de uso expostos à árvore semântica | aprovado |
| Texto ampliado | controle principal renderizado com escala de texto de 200% sem exceção | aprovado |
| Tema e contraste | testes existentes dos tokens de tema claro, escuro e alto contraste | aprovado |
| Layout responsivo | testes existentes de telas pequenas, orientação e texto grande | aprovado |
| Regressão visual | imagens de referência das telas cobertas pelos testes golden | aprovado |

## Melhorias implementadas

- inclusão explícita de rótulo, função de botão, dica e ação de longa duração no controle de emergência;
- inclusão explícita de rótulo, função de botão, dica e ação no botão de confirmação prolongada;
- teste dedicado à ampliação de texto em 200%;
- atualização da imagem de referência da tela de recuperação de senha;
- execução automática dos testes e da análise estática no GitHub Actions.

## Referência de qualidade

A WCAG 2.2 foi usada como referência de princípios aplicáveis, como nome acessível, operação compreensível, ampliação de texto e tamanho de alvo. A especificação está disponível em <https://www.w3.org/TR/WCAG22/>.

A W3C informa que ferramentas automáticas não conseguem determinar sozinhas se um produto é acessível e que avaliação humana continua necessária. Ver <https://www.w3.org/WAI/test-evaluate/>.

## Limites desta auditoria

Os testes executados não avaliam diretamente:

- pronúncia e ordem de leitura em TalkBack e VoiceOver;
- navegação por teclado, controle por interruptor e acesso por voz em dispositivos reais;
- percepção de contraste sob diferentes condições visuais e de luminosidade;
- compreensão das mensagens por pessoas idosas com diferentes níveis de letramento;
- tempo, fadiga, destreza e ocorrência de toques acidentais no uso prolongado;
- todas as combinações de resolução, fabricante e versão de Android e iOS.

## Roteiro manual obrigatório antes da produção

1. executar os fluxos de idoso e cuidador com TalkBack em Android físico;
2. executar os mesmos fluxos com VoiceOver em iPhone físico;
3. conferir foco, ordem de leitura, rótulo, dica, estado e retorno após diálogos;
4. testar escala máxima de fonte e tamanho de exibição;
5. testar orientação, teclado externo e mecanismo de acesso alternativo disponível;
6. validar contraste de todos os estados, inclusive desabilitado, erro e carregamento;
7. observar tarefas reais com pessoas idosas, registrar barreiras e repetir a avaliação;
8. guardar modelo do aparelho, sistema, versão do aplicativo, roteiro e resultado.

## Critério de manutenção

Toda alteração em controles críticos deve manter rótulo semântico, instrução compatível com a ação, área tátil mínima e teste com texto ampliado. Falhas na suíte bloqueiam a integração contínua. A auditoria manual deve ser repetida antes de cada versão destinada a usuários reais.
