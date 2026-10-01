// SGO-DIROB · EMOP-RJ — Edge Function "admin-usuarios"
// Cria e administra logins. Só atende quem é ADMINISTRADOR ATIVO no sistema.
// A chave secreta (service role) fica só aqui no servidor, nunca no site.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const resposta = (corpo: unknown, status = 200) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const erro = (msg: string, status = 400) => resposta({ erro: msg }, status);

const PAPEIS = ["admin", "editor", "leitura"];
const texto = (v: unknown, max = 200) => (typeof v === "string" ? v.trim().slice(0, max) : "") || null;

function traduzir(m: string): string {
  if (/already been registered|already registered|already exists/i.test(m)) return "Já existe um usuário com este e-mail.";
  if (/password/i.test(m) && /(short|least|weak)/i.test(m)) return "Senha fraca: use pelo menos 8 caracteres.";
  if (/invalid.*email|email.*invalid/i.test(m)) return "E-mail inválido.";
  if (/administrador ativo/i.test(m)) return "O sistema precisa de pelo menos um administrador ativo.";
  return m;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return erro("Método não permitido.", 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const chaveSecreta = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!chaveSecreta) return erro("Função sem a chave de serviço configurada.", 500);
  const adm = createClient(url, chaveSecreta, { auth: { persistSession: false, autoRefreshToken: false } });

  // 1) Quem está chamando? Tem que ser administrador ativo.
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return erro("Faça login novamente.", 401);
  const { data: quem, error: eQuem } = await adm.auth.getUser(token);
  if (eQuem || !quem?.user) return erro("Sessão expirada. Faça login novamente.", 401);
  const { data: meuPerfil } = await adm.from("perfis").select("papel, ativo").eq("id", quem.user.id).maybeSingle();
  if (!meuPerfil || meuPerfil.papel !== "admin" || !meuPerfil.ativo) return erro("Apenas administradores podem fazer isso.", 403);

  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return erro("Pedido inválido."); }
  const acao = String(b.acao || "");
  const id = texto(b.id, 64);
  const proprio = id === quem.user.id;

  try {
    // 2) Criar login + perfil
    if (acao === "criar") {
      const email = texto(b.email, 200)?.toLowerCase();
      const senha = typeof b.senha === "string" ? b.senha : "";
      const papel = PAPEIS.includes(String(b.papel)) ? String(b.papel) : "leitura";
      if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return erro("Informe um e-mail válido.");
      if (senha.length < 8) return erro("A senha inicial precisa ter pelo menos 8 caracteres.");
      const nome = texto(b.nome) || email.split("@")[0];
      const { data, error } = await adm.auth.admin.createUser({
        email, password: senha, email_confirm: true, user_metadata: { nome },
      });
      if (error) return erro(traduzir(error.message));
      const { error: eP } = await adm.from("perfis").upsert({
        id: data.user.id, email, nome, papel,
        cargo: texto(b.cargo), matricula: texto(b.matricula, 40), lotacao: texto(b.lotacao),
        telefone: texto(b.telefone, 40), ativo: true, trocar_senha: true,
      });
      if (eP) { await adm.auth.admin.deleteUser(data.user.id); return erro(traduzir(eP.message)); }
      return resposta({ ok: true, id: data.user.id });
    }

    // 3) Lista com dados do login (último acesso, e-mail confirmado)
    if (acao === "listar") {
      const todos: Record<string, unknown>[] = [];
      for (let page = 1; page < 50; page++) {
        const { data, error } = await adm.auth.admin.listUsers({ page, perPage: 200 });
        if (error) return erro(traduzir(error.message));
        data.users.forEach((u) => todos.push({ id: u.id, email: u.email, ultimo_login: u.last_sign_in_at, criado: u.created_at }));
        if (data.users.length < 200) break;
      }
      return resposta({ ok: true, usuarios: todos });
    }

    if (!id) return erro("Usuário não informado.");

    // 4) Redefinir senha (o usuário troca no próximo login)
    if (acao === "redefinir_senha") {
      const senha = typeof b.senha === "string" ? b.senha : "";
      if (senha.length < 8) return erro("A nova senha precisa ter pelo menos 8 caracteres.");
      const { error } = await adm.auth.admin.updateUserById(id, { password: senha });
      if (error) return erro(traduzir(error.message));
      await adm.from("perfis").update({ trocar_senha: !proprio }).eq("id", id);
      return resposta({ ok: true });
    }

    // 5) Trocar e-mail de login
    if (acao === "alterar_email") {
      const email = texto(b.email, 200)?.toLowerCase();
      if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return erro("Informe um e-mail válido.");
      const { error } = await adm.auth.admin.updateUserById(id, { email, email_confirm: true });
      if (error) return erro(traduzir(error.message));
      await adm.from("perfis").update({ email }).eq("id", id);
      return resposta({ ok: true });
    }

    // 6) Desativar / reativar (bloqueia o login sem apagar o histórico)
    if (acao === "desativar" || acao === "reativar") {
      if (proprio) return erro("Você não pode desativar o seu próprio acesso.");
      const ativo = acao === "reativar";
      const { error: eP } = await adm.from("perfis").update({ ativo }).eq("id", id);
      if (eP) return erro(traduzir(eP.message));
      const { error } = await adm.auth.admin.updateUserById(id, { ban_duration: ativo ? "none" : "876000h" });
      if (error) { await adm.from("perfis").update({ ativo: !ativo }).eq("id", id); return erro(traduzir(error.message)); }
      return resposta({ ok: true });
    }

    // 7) Excluir de vez (o histórico das obras continua, com o nome gravado nele)
    if (acao === "excluir") {
      if (proprio) return erro("Você não pode excluir o seu próprio usuário.");
      const { data: alvo } = await adm.from("perfis").select("papel, ativo").eq("id", id).maybeSingle();
      if (alvo?.papel === "admin" && alvo?.ativo) {
        const { count } = await adm.from("perfis").select("id", { count: "exact", head: true }).eq("papel", "admin").eq("ativo", true);
        if ((count || 0) <= 1) return erro("O sistema precisa de pelo menos um administrador ativo.");
      }
      const { error } = await adm.auth.admin.deleteUser(id);
      if (error) return erro(traduzir(error.message));
      return resposta({ ok: true });
    }

    return erro("Ação desconhecida.");
  } catch (e) {
    return erro(traduzir(String((e as Error)?.message || e)), 500);
  }
});
