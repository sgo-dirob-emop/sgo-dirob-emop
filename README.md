# SGO-DIROB · Sistema de Gestão de Obras da Diretoria de Obras · EMOP-RJ

Sistema web (abre no navegador do computador e do celular) que acompanha cada obra da DIROB
do contrato ao encerramento, seguindo o **Manual de Rotinas e Procedimentos da DIROB**
(`docs/Manual_de_Rotinas_DIROB_EMOP-RJ.pdf`): etapas por POP, checklists, medições com
planilha/memória/mapa de tempo/fotos, aditivos, prazos, alertas e geração dos 24 documentos.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O sistema inteiro (telas, regras, documentos). |
| `config.js` | Endereço e chave pública do banco Supabase. **Preencher antes de publicar.** |
| `supabase/schema.sql` | Cria as tabelas, permissões e auditoria no Supabase. |
| `manifest.json` | Permite "instalar" o sistema no celular. |
| `docs/` | Manual da DIROB e o protótipo original feito no Claude Desktop. |

## Colocar no ar (passo a passo)

1. **Criar o banco**: em https://supabase.com crie um projeto novo (ex.: `sgo-dirob-emop`), região São Paulo.
2. **Montar as tabelas**: no projeto, vá em *SQL Editor > New query*, cole todo o conteúdo de
   `supabase/schema.sql` e clique em *Run*.
3. **Bloquear cadastro aberto**: *Authentication > Sign In / Providers > Email* — desligue
   "Allow new users to sign up". Só o administrador cria usuários.
4. **Criar seu usuário**: *Authentication > Users > Add user* (e-mail e senha, marque "Auto Confirm").
   Depois rode no SQL Editor (trocando o e-mail):
   `update public.perfis set papel = 'admin' where email = 'seu-email@exemplo.com';`
5. **Ligar o sistema ao banco**: em *Project Settings > API* copie a *Project URL* e a chave *anon public*
   e cole em `config.js`.
6. **Publicar**: qualquer hospedagem de site estático serve (o mesmo servidor do Planeja.ai via FTP,
   Netlify, Vercel ou Cloudflare Pages). Basta enviar os arquivos da raiz.
7. **Endereço do site no Supabase**: *Authentication > URL Configuration* — coloque o endereço
   publicado em "Site URL" (necessário para o link de "Esqueci a senha").

Sem `config.js` preenchido o sistema abre em **modo local** (dados só no navegador), útil para testes.

## Níveis de acesso

- **Administrador** — tudo, inclusive a tela *Usuários* para definir o acesso dos outros.
- **Pode lançar e alterar** — cadastra obras, medições, aditivos, emite documentos.
- **Somente consulta** — vê tudo, não altera nada (padrão de todo usuário novo).

Toda alteração fica registrada na tabela `auditoria` (quem, quando, antes e depois).
