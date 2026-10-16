// Ligação com o Supabase. Preencha com os dados do seu projeto (Project Settings > API):
//   url     = "Project URL"           (ex.: https://abcdefgh.supabase.co)
//   anonKey = chave "anon public"     (começa com eyJ...)
// A chave anon é pública por desenho: a segurança vem das regras do banco (supabase/schema.sql).
// NUNCA coloque aqui a chave "service_role".
// Deixando os dois vazios, o app roda em modo local (dados só neste aparelho).
window.SUPABASE_CONFIG = {
  url: '',
  anonKey: ''
};
