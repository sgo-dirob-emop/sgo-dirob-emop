// Configuração do banco online (Supabase) do SGO-DIROB.
// Preencha com os dados do projeto: Supabase > Project Settings > API.
// A "anon key" é pública por natureza (a segurança fica nas regras do banco, em supabase/schema.sql).
// Se ficar em branco, o sistema abre em "modo local" (dados só no navegador), como no protótipo.
window.SGO_CONFIG = {
  supabaseUrl: "",      // ex.: "https://abcdefghijkl.supabase.co"
  supabaseAnonKey: ""   // ex.: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
};
