# Configurar o ELO com o Supabase

Com o Supabase, cada pessoa entra com a própria conta no próprio celular e os
dados do casal sincronizam sozinhos. Sem configuração, o app continua no modo
local (dados só no aparelho), como antes.

## 1. Criar o projeto

1. Entre em <https://supabase.com> → **New project**.
2. Escolha um nome (ex.: `elo`), crie uma senha para o banco e escolha a região
   **South America (São Paulo)**.

## 2. Criar as tabelas

1. No painel do projeto, abra **SQL Editor** → **New query**.
2. Cole todo o conteúdo de [`supabase/schema.sql`](supabase/schema.sql) e clique em **Run**.
   Deve aparecer "Success. No rows returned". Pode rodar de novo sem problemas.

## 3. Configurar o login

Em **Authentication → URL Configuration**:

- **Site URL**: o endereço do app na Vercel, ex.: `https://elo-marriage.vercel.app`
- **Redirect URLs**: adicione o mesmo endereço.

Em **Authentication → Sign In / Providers → Email**:

- Deixe **Email** habilitado.
- **Confirm email**: se ficar ligado, cada pessoa recebe um link para confirmar a
  conta. O e-mail padrão do Supabase tem limite baixo de envios por hora; como
  são só duas contas, desligar essa opção também é aceitável.

## 4. Conectar o app

1. Em **Project Settings → API** (ou **Data API** / **API Keys**), copie:
   - **Project URL** (ex.: `https://abcdxyz.supabase.co`)
   - a chave **anon** / **publishable** (a pública).
2. Cole no arquivo [`config.js`](config.js):

   ```js
   window.ELO_CONFIG = {
     supabaseUrl: 'https://abcdxyz.supabase.co',
     supabaseAnonKey: 'eyJhbGciOi...'
   };
   ```

3. Faça commit e push. A Vercel publica sozinha.

> A chave anon/publishable pode ficar no código: ela é pública por design, e
> quem protege os dados são as regras do banco (RLS). **Nunca** use a chave
> `service_role` / `secret` no `config.js`.

## 5. Usar

1. **Pessoa 1** abre o app → **Criar conta** → **Criar casal** (preenche os dois nomes).
   Se já usava o ELO nesse celular, pode marcar a opção de levar os dados para a nuvem.
2. Aparece um **código de convite** no Início (e em Mais → Configurações).
   Toque em **Compartilhar convite** e mande pelo WhatsApp.
3. **Pessoa 2** abre o app → **Criar conta** → digita o código em **Entrar no casal**.

## O que fica protegido (regras no banco, não só na tela)

| Dado | Quem vê |
| --- | --- |
| "Meu espaço" (diário) | só o autor |
| Respostas de segurança do check-in | só o autor |
| Check-in da semana | o autor; o outro só depois de enviar o próprio check-in da mesma semana |
| Ações, reconhecimentos, conflitos, nomes | os dois |
| Qualquer dado do casal | ninguém de fora do casal |

Cada casal aceita só duas contas. Depois que a segunda pessoa entra, o código
de convite deixa de funcionar.
