/* Configuração do Supabase.
   Pegue os valores em: Supabase → Project Settings → API (ou "Data API").
   A chave "anon"/"publishable" é pública por design: quem protege os dados
   são as regras de RLS em supabase/schema.sql. NUNCA coloque aqui a
   chave "service_role"/"secret".
   Deixe em branco para usar o modo local (dados só no aparelho). */
window.ELO_CONFIG = {
  supabaseUrl: 'https://wmazzcwunzbqhrkapyla.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtYXp6Y3d1bnpicWhya2FweWxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0NTQwNzEsImV4cCI6MjEwNjAzMDA3MX0.GI26A5jM1aUKJCCsd03sZ9luh_7tinI7WFUpyt9maEA
'
};
