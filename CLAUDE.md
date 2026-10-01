# CLAUDE.md — SGO-DIROB (EMOP-RJ)

Guia para o Claude Code. Leia também `MEMORIA.md` (linha do tempo e pendências) antes de mexer,
e atualize-o ao final de cada sessão relevante.

**Este projeto não tem nenhuma relação com o Planeja.ai / Marcena Rio.** Não reaproveite banco,
chaves, servidor nem código de lá sem pedido explícito.

## O que é
Sistema de gestão de obras da Diretoria de Obras (DIROB) da EMOP-RJ (empresa pública estadual).
Segue o Manual de Rotinas da DIROB (`docs/Manual_de_Rotinas_DIROB_EMOP-RJ.pdf`), os POPs-DIROB-01 a 10,
o Regimento Interno da EMOP e a Lei 13.303/2016. Usuário final: gerentes, fiscais e coordenadores
(COBRA/DOBRA) — linguagem pt-BR, formal, termos da administração pública.

## Formato
- Arquivo único `index.html` (HTML+CSS+JS inline, sem build, sem npm). Edite direto.
- `config.js` define `window.SGO_CONFIG = {supabaseUrl, supabaseAnonKey}`. Vazio = modo local (localStorage).
- Supabase: tabela genérica `documentos(caminho pk, colecao, dados jsonb)` + `perfis` + `auditoria`.
  O código usa um adaptador estilo "documento" (`S.db.doc(caminho).get/set/delete/onSnapshot`,
  `S.db.collection(colecao).get/onSnapshot`) — ver `bancoSupabase()` em `index.html`.
  Caminhos: `obras/<id>`, `planilhas/<id>`, `obras/<id>/medicoes/<n>`, `obras/<id>/fotos/<id>`, `config/modelos`.
- Permissões: RLS no banco (`pode_editar()` = papel admin/editor). Erro de RLS vira `code:"invalid_argument"`
  e a UI avisa "acesso só de leitura". Papéis: `admin`, `editor`, `leitura`.
- Tempo real: canal `postgres_changes` na tabela `documentos`.

## Estrutura do `index.html`
- `ETAPAS` — fluxo da obra (contrato → partida → execução → recebimento → encerrada), cada uma com POP,
  campos obrigatórios (`req`), checklist (`chk`, Anexo B do manual) e documentos sugeridos (`docs`).
- `CAMPOS` / `GRUPOS` — campos da obra. `calc(o)` — valores, saldos, prazos. `alertas(o)` — alertas do painel.
- `DOCS` / `MODELOS_PADRAO` — os 24 documentos; `x` = campos novos pedidos, `fx` = efeito ao "registrar
  como emitido" (devolve dados à obra), `texto` com `{{campo}}` e `{{x.campo}}`.
- Medição detalhada: `tMed`, `tMedir`, `confere`, `verBoletim`, `comprimir` (fotos 1280px JPEG).
- Telas: `tPainel`, `tObras`, `tObra`, `tModelos`, `tAjuda`, `tUsuarios`. `render()` redesenha tudo.
- Ações: delegação de eventos `click`/`change`/`input` no fim do script (`data-acao`, `data-doc`...).

## Regras
- Todo texto visível em pt-BR. Datas dd/mm/aaaa, moeda R$.
- Nunca deixe o fluxo avançar de etapa sem os campos obrigatórios e o checklist (é a regra do manual).
- Medição nunca pode passar a quantidade contratada do item nem o saldo do contrato/empenho.
- Mudanças no banco: escreva SQL idempotente em `supabase/` e envie ao usuário o arquivo COMPLETO
  para colar no SQL Editor (o usuário não é programador).
- Teste no navegador (Playwright/Chromium já instalado) antes de commitar.
