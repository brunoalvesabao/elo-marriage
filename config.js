/* Configuração do Supabase.
   Pegue os valores em: Supabase → Project Settings → API (ou "Data API").
   A chave "anon"/"publishable" é pública por design: quem protege os dados
   são as regras de RLS em supabase/schema.sql. NUNCA coloque aqui a
   chave "service_role"/"secret".
   Deixe em branco para usar o modo local (dados só no aparelho). */
window.ELO_CONFIG = {
  supabaseUrl: '',
  supabaseAnonKey: ''
};
