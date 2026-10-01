-- =====================================================================
-- SGO-DIROB · EMOP-RJ — 002: administração de usuários e perfis
-- Rode DEPOIS do schema.sql. Cole INTEIRO no SQL Editor > New query > Run.
-- Pode ser executado mais de uma vez sem estragar nada.
-- =====================================================================

-- 1) Novos dados do perfil
alter table public.perfis add column if not exists cargo         text;
alter table public.perfis add column if not exists matricula     text;
alter table public.perfis add column if not exists lotacao       text;
alter table public.perfis add column if not exists telefone      text;
alter table public.perfis add column if not exists ativo         boolean not null default true;
alter table public.perfis add column if not exists trocar_senha  boolean not null default false;
alter table public.perfis add column if not exists ultimo_acesso timestamptz;
alter table public.perfis add column if not exists atualizado_em timestamptz not null default now();

-- 2) Usuário desativado perde o acesso na hora (mesmo com a sessão aberta)
create or replace function public.usuario_ativo()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select ativo from public.perfis where id = auth.uid()), false)
$$;

create or replace function public.meu_papel()
returns text language sql stable security definer set search_path = public as $$
  select papel from public.perfis where id = auth.uid() and ativo
$$;

create or replace function public.pode_editar()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select papel in ('admin','editor') from public.perfis where id = auth.uid() and ativo), false)
$$;

drop policy if exists "docs: logado lê" on public.documentos;
create policy "docs: logado lê" on public.documentos
  for select to authenticated using (public.usuario_ativo());

drop policy if exists "perfis: logado lê" on public.perfis;
create policy "perfis: logado lê" on public.perfis
  for select to authenticated using (id = auth.uid() or public.usuario_ativo());

-- 3) Ações do próprio usuário (sem poder mudar o próprio acesso)
create or replace function public.registrar_acesso()
returns void language sql security definer set search_path = public as $$
  update public.perfis set ultimo_acesso = now() where id = auth.uid()
$$;

create or replace function public.senha_trocada()
returns void language sql security definer set search_path = public as $$
  update public.perfis set trocar_senha = false where id = auth.uid()
$$;

create or replace function public.atualizar_meus_dados(p_nome text, p_telefone text)
returns void language sql security definer set search_path = public as $$
  update public.perfis set nome = nullif(trim(p_nome),''), telefone = nullif(trim(p_telefone),'')
  where id = auth.uid()
$$;

grant execute on function public.registrar_acesso(), public.senha_trocada(),
  public.atualizar_meus_dados(text,text) to authenticated;

-- 4) Trava: o sistema nunca fica sem um administrador ativo
create or replace function public.proteger_ultimo_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'DELETE' and old.papel = 'admin' and old.ativo)
     or (tg_op = 'UPDATE' and old.papel = 'admin' and old.ativo and (new.papel <> 'admin' or not new.ativo)) then
    if (select count(*) from public.perfis where papel = 'admin' and ativo and id <> old.id) = 0 then
      raise exception 'O sistema precisa de pelo menos um administrador ativo.';
    end if;
  end if;
  if tg_op = 'UPDATE' then new.atualizado_em := now(); return new; end if;
  return old;
end $$;

drop trigger if exists ultimo_admin on public.perfis;
create trigger ultimo_admin before update or delete on public.perfis
  for each row execute function public.proteger_ultimo_admin();

-- 5) Auditoria das mudanças de perfil (quem mudou o acesso de quem)
create or replace function public.auditar_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- registrar_acesso() só muda ultimo_acesso: não precisa ir para a auditoria
  if tg_op = 'UPDATE' and (to_jsonb(old) - 'ultimo_acesso' - 'atualizado_em') = (to_jsonb(new) - 'ultimo_acesso' - 'atualizado_em') then
    return new;
  end if;
  insert into public.auditoria (usuario, operacao, caminho, antes, depois)
  values (auth.uid(), tg_op, 'perfis/' || coalesce(new.id, old.id)::text,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

drop trigger if exists auditoria_perfis on public.perfis;
create trigger auditoria_perfis after insert or update or delete on public.perfis
  for each row execute function public.auditar_perfil();

-- 6) Conferência: deve listar você como admin e ativo
select email, nome, papel, ativo from public.perfis order by nome;
