// Ligação com o Supabase. Preencha com os dados do seu projeto (botão Connect, ou Project Settings > API Keys):
//   url     = "Project URL"           (ex.: https://abcdefgh.supabase.co)
//   anonKey = chave pública: "Publishable key" (começa com sb_publishable_...) ou a antiga "anon" (eyJ...)
// A chave anon é pública por desenho: a segurança vem das regras do banco (supabase/schema.sql).
// NUNCA coloque aqui a chave "service_role" nem a "secret" (sb_secret_...).
// Deixando os dois vazios, o app roda em modo local (dados só neste aparelho).
window.SUPABASE_CONFIG = {
  url: 'https://spzpbjzmyczbkeyjimdl.supabase.co',
  anonKey: 'sb_publishable_itpZBr32H7KlHxe-lqtrTQ_x8WZ6n01'
};
