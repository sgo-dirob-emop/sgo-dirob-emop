# MEMÓRIA — SGO-DIROB (EMOP-RJ)

## Linha do tempo (mais recente no topo)

### 01/10/2026 — Administração de usuários
- Sistema no ar em https://sgo-dirob-emop.vercel.app, login real testado pelo usuário (admin: engenharia.mmxconstrucoes@gmail.com).
- Menu **Usuários** completo (só admin): criar login com senha provisória, cargo, matrícula, lotação, telefone,
  nível de acesso; editar; trocar e-mail; redefinir senha; desativar/reativar (ban no Auth + `perfis.ativo`); excluir.
- Primeiro acesso obriga a criar senha própria (`perfis.trocar_senha`). Tela **Minha conta** para todos (nome, telefone, senha).
- Banco: `supabase/002_usuarios.sql` (colunas novas em `perfis`, RLS exige usuário ativo, trava do último admin, auditoria de perfis).
- Edge Function `admin-usuarios` (`supabase/functions/admin-usuarios/index.ts`) usa a service role no servidor; valida que quem chama é admin ativo.

### 01/10/2026 — Protótipo vira sistema online
- Repositório criado a partir do protótipo feito no Claude Desktop (artifact "SGO-DIROB"; cópia em
  `docs/prototipo_original.html`).
- Troca do banco do protótipo (artifact) por **Supabase**: login por e-mail/senha, perfis
  (admin/editor/leitura), RLS, auditoria de alterações, tempo real. Sem configuração → modo local.
- Tela **Usuários** (só admin) para definir o acesso; histórico da obra agora mostra quem fez.
- Download dos documentos/boletins passa a ser pelo navegador.
- Testado em Chromium com Supabase simulado: login, senha errada, criar obra, importar planilha,
  recarregar e ler do banco.

## Herdado do protótipo (já funciona)
- Fluxo em 5 etapas com POPs, campos obrigatórios e checklist do Anexo B.
- Medição completa: planilha contratual colada do Excel, memória de cálculo, mapa de tempo, fotos,
  Administração Local proporcional, conferência automática, boletim de medição.
- 24 documentos dos POP-01 a POP-10 com preenchimento só do que é novo e efeitos na obra.
- Painel da Diretoria, alertas, relatório mensal.

## Pendências / próximos passos
- [x] Projeto Supabase criado (`agssrmsvmdiyfhjbjood`, São Paulo) e `config.js` preenchido com a publishable key (01/10/2026).
- [ ] Confirmar que `supabase/schema.sql` foi rodado e testar login real; publicar o site.
- [x] Publicado na Vercel (time EMOP-DIROB, plano Hobby): **https://sgo-dirob-emop.vercel.app** — deploy automático a cada push no `main`; `vercel.json` desvia `/docs`, `/supabase` e os .md para a página inicial (01/10/2026).
- [ ] Usuário rodar `002_usuarios.sql` e publicar a Edge Function `admin-usuarios` (Verify JWT desligado — a função valida sozinha).
- [ ] Supabase > Authentication > URL Configuration: Site URL = https://sgo-dirob-emop.vercel.app e Redirect URL = https://sgo-dirob-emop.vercel.app/**.
- [ ] Fotos: hoje ficam dentro do banco (jsonb, ~150 KB cada). Migrar para Supabase Storage quando o volume crescer.
- [ ] Planilha contratual limitada a ~1.200 itens (limite herdado) — revisar agora que o banco aguenta mais.
- [ ] Modelos oficiais da EMOP (Memorando de Início, boletim de medição) para substituir os textos provisórios.
- [ ] Nomes do Diretor e Coordenadores nas assinaturas.
- [ ] Cronograma físico-financeiro mês a mês (previsto x realizado no painel).
- [ ] Separar a obra de exemplo ("EXEMPLO · Reforma de Delegacia") — existia só no banco do artifact, não veio junto.
