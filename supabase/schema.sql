-- =====================================================================
-- SGO-DIROB · EMOP-RJ — estrutura do banco no Supabase
-- Cole este arquivo INTEIRO no Supabase: SQL Editor > New query > Run.
-- Pode ser executado mais de uma vez sem estragar nada.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Perfis de usuário (quem pode ver e quem pode alterar)
--    papel: 'admin'  -> tudo, inclusive mudar o papel dos outros
--           'editor' -> lança e altera obras, medições, documentos
--           'leitura'-> só consulta (padrão de quem acabou de ser criado)
-- ---------------------------------------------------------------------
create table if not exists public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  nome       text,
  papel      text not null default 'leitura' check (papel in ('admin','editor','leitura')),
  criado_em  timestamptz not null default now()
);

-- cria o perfil automaticamente quando um usuário é criado no Supabase Auth
create or replace function public.criar_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfis (id, email, nome)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.criar_perfil();

-- perfis de usuários que já existiam antes deste script
insert into public.perfis (id, email, nome)
select id, email, split_part(email,'@',1) from auth.users
on conflict (id) do nothing;

-- funções auxiliares usadas nas regras de segurança
create or replace function public.meu_papel()
returns text language sql stable security definer set search_path = public as $$
  select papel from public.perfis where id = auth.uid()
$$;

create or replace function public.pode_editar()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select papel in ('admin','editor') from public.perfis where id = auth.uid()), false)
$$;

alter table public.perfis enable row level security;

drop policy if exists "perfis: logado lê" on public.perfis;
create policy "perfis: logado lê" on public.perfis
  for select to authenticated using (true);

drop policy if exists "perfis: admin altera" on public.perfis;
create policy "perfis: admin altera" on public.perfis
  for update to authenticated using (public.meu_papel() = 'admin') with check (public.meu_papel() = 'admin');

drop policy if exists "perfis: usuário muda o próprio nome" on public.perfis;
-- (o nome é alterado só pelo admin nesta versão)

-- ---------------------------------------------------------------------
-- 2) Documentos do sistema
--    O SGO-DIROB guarda tudo como "documentos" identificados por caminho,
--    exatamente como o protótipo fazia:
--      obras/<id>                     -> dados da obra (etapa, aditivos, histórico...)
--      planilhas/<id>                 -> planilha contratual da obra
--      obras/<id>/medicoes/<n>        -> medição detalhada nº n
--      obras/<id>/fotos/<fotoId>      -> foto do relatório fotográfico
--      config/modelos                 -> textos dos modelos de documento
-- ---------------------------------------------------------------------
create table if not exists public.documentos (
  caminho         text primary key,
  colecao         text not null,
  dados           jsonb not null default '{}'::jsonb,
  atualizado_em   timestamptz not null default now(),
  atualizado_por  uuid references auth.users(id) on delete set null
);
create index if not exists documentos_colecao_idx on public.documentos (colecao);

create or replace function public.carimbar_documento()
returns trigger language plpgsql as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := auth.uid();
  return new;
end $$;

drop trigger if exists carimbo on public.documentos;
create trigger carimbo before insert or update on public.documentos
  for each row execute function public.carimbar_documento();

alter table public.documentos enable row level security;

drop policy if exists "docs: logado lê" on public.documentos;
create policy "docs: logado lê" on public.documentos
  for select to authenticated using (true);

drop policy if exists "docs: editor inclui" on public.documentos;
create policy "docs: editor inclui" on public.documentos
  for insert to authenticated with check (public.pode_editar());

drop policy if exists "docs: editor altera" on public.documentos;
create policy "docs: editor altera" on public.documentos
  for update to authenticated using (public.pode_editar()) with check (public.pode_editar());

drop policy if exists "docs: editor exclui" on public.documentos;
create policy "docs: editor exclui" on public.documentos
  for delete to authenticated using (public.pode_editar());

-- ---------------------------------------------------------------------
-- 3) Auditoria: toda alteração fica registrada (quem, quando, antes/depois)
-- ---------------------------------------------------------------------
create table if not exists public.auditoria (
  id          bigserial primary key,
  quando      timestamptz not null default now(),
  usuario     uuid,
  operacao    text not null,
  caminho     text not null,
  antes       jsonb,
  depois      jsonb
);
create index if not exists auditoria_caminho_idx on public.auditoria (caminho, quando desc);

create or replace function public.auditar_documento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- fotos não são copiadas inteiras para a auditoria (só o registro da operação)
  if tg_op = 'DELETE' then
    insert into public.auditoria (usuario, operacao, caminho, antes)
    values (auth.uid(), tg_op, old.caminho, case when old.colecao like '%/fotos' then null else old.dados end);
    return old;
  else
    insert into public.auditoria (usuario, operacao, caminho, antes, depois)
    values (auth.uid(), tg_op, new.caminho,
            case when tg_op = 'UPDATE' and new.colecao not like '%/fotos' then old.dados end,
            case when new.colecao like '%/fotos' then null else new.dados end);
    return new;
  end if;
end $$;

drop trigger if exists auditoria_docs on public.documentos;
create trigger auditoria_docs after insert or update or delete on public.documentos
  for each row execute function public.auditar_documento();

alter table public.auditoria enable row level security;
drop policy if exists "auditoria: admin lê" on public.auditoria;
create policy "auditoria: admin lê" on public.auditoria
  for select to authenticated using (public.meu_papel() = 'admin');

-- ---------------------------------------------------------------------
-- 4) Tempo real: todos que estão com o sistema aberto veem as mudanças
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'documentos') then
    execute 'alter publication supabase_realtime add table public.documentos';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5) Depois de criar o SEU usuário (Authentication > Users > Add user),
--    rode a linha abaixo trocando o e-mail para virar administrador:
--
--    update public.perfis set papel = 'admin' where email = 'seu-email@exemplo.com';
-- ---------------------------------------------------------------------
