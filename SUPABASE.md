# Subir o Rei da Faxina no Supabase

Perfis: **1 administrador** (100% adm, não joga por padrão) e até **4 jogadores**, que fazem o próprio cadastro no app.

## Passo a passo

1. **Criar o projeto** em supabase.com (New project). Guarde a senha do banco.
2. **Definir o e-mail do administrador.** Abra `supabase/schema.sql`, procure `COLOQUE_SEU_EMAIL_AQUI@exemplo.com` e troque pelo seu e-mail.
3. **Rodar o schema.** No Supabase, SQL Editor, New query, cole o arquivo inteiro e clique em Run. Deve terminar sem erro.
4. **Desligar a confirmação de e-mail.** Authentication, Providers, Email, desative "Confirm email". Assim o cadastro entra direto.
5. **Colar as chaves.** Project Settings, API. Copie "Project URL" e a chave "anon public" para o `config.js`. Nunca use a `service_role`.
6. **Publicar.** Suba os arquivos no GitHub e ative Settings, Pages, branch `main`, pasta raiz.
7. **Criar o administrador primeiro.** Abra o site, "Criar meu cadastro" com o e-mail do passo 2. Faça isso antes de divulgar o link, para ninguém tomar o e-mail de admin.
8. **Escolher as tarefas.** Em Ajustes, "Tarefas da casa", o admin marca as tarefas que valem e ajusta os pontos.
9. **Passar o código da casa.** O admin vê o código na tela Início ou em Ajustes, Participantes. Cada jogador abre o site, "Criar meu cadastro" e informa o código.

## Regras
- Só o e-mail definido no passo 2 vira administrador. Não existe como outro perfil virar admin pelo app.
- Máximo de 4 jogadores. O 5º é bloqueado.
- O admin pode ativar "Também jogar" em Ajustes se quiser participar.
- Para impedir novos cadastros, feche-os em Ajustes, Participantes. O código da casa pode ser trocado lá também.

## Limites
- Atualização entre aparelhos a cada 20 segundos (ou na hora, após cada ação).
- Esqueceu a senha: redefina em Authentication, Users, no painel do Supabase.
- Backup: use o painel do Supabase (Database, Backups) ou exporte as tabelas.
- Sem `url` e `anonKey` no `config.js`, o app roda em modo local (dados só no aparelho).
