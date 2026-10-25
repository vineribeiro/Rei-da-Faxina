# Tutorial: cadastro no Supabase e Rei da Faxina no ar

Tempo: cerca de 20 minutos. Custo: zero (plano gratuito do Supabase e GitHub Pages).

Você vai fazer 3 coisas: criar sua conta no Supabase, montar o banco do jogo e publicar o app.

---

## Parte 1. Criar a conta no Supabase

1. Abra **supabase.com** e clique em **Start your project**.
2. Entre com **Continue with GitHub** (recomendado, você já tem GitHub) ou crie conta com e-mail e senha. Se usar e-mail, confirme pelo link que chega na caixa de entrada.
3. Se pedir para criar uma **Organization**: nome "Casa", tipo **Personal**, plano **Free**.
4. Clique em **New project** e preencha:
   - **Name:** `rei-da-faxina`
   - **Database password:** clique em **Generate a password** e guarde essa senha num lugar seguro (você quase não vai usar, mas não dá para ver de novo).
   - **Region:** **South America (São Paulo)**
   - **Plan:** Free
5. Clique em **Create new project** e espere 1 a 2 minutos até o painel abrir.

## Parte 2. Criar o banco do jogo

1. No GitHub, abra o arquivo `supabase/schema.sql` do repositório e clique no ícone de lápis (editar).
2. Na linha que tem `COLOQUE_SEU_EMAIL_AQUI@exemplo.com`, troque pelo **e-mail que será do administrador**. Só esse e-mail vira admin. Não clique em salvar ainda: apenas **copie o arquivo inteiro** (Ctrl+A, Ctrl+C).
3. No Supabase, menu da esquerda, clique em **SQL Editor** e depois em **New query**.
4. Cole o conteúdo e clique em **Run** (ou Ctrl+Enter).
5. Deve aparecer **Success**. Se aparecer erro, confira se copiou o arquivo completo e rode de novo em uma query nova.

## Parte 3. Ajustar o cadastro

1. Menu **Authentication**, depois **Sign In / Providers** (em alguns painéis só **Providers**), depois **Email**.
2. Deixe o Email **ligado** e **desligue "Confirm email"**. Assim cada jogador entra na hora, sem precisar abrir e-mail.
3. Clique em **Save**.

## Parte 4. Ligar o app ao banco

1. No topo do painel, clique em **Connect**. Anote:
   - **Project URL** (algo como `https://abcdefgh.supabase.co`)
   - **Publishable key** (começa com `sb_publishable_`). Se não achar, vá em **Project Settings**, **API Keys**. A chave antiga **anon** também funciona.
2. No GitHub, abra o arquivo `config.js`, clique no lápis e preencha:

```js
window.SUPABASE_CONFIG = {
  url: 'https://SEU-PROJETO.supabase.co',
  anonKey: 'sb_publishable_SUA_CHAVE'
};
```

3. Clique em **Commit changes**.

Nunca use a chave **secret** nem a **service_role**. Elas dão acesso total ao banco. A publishable é feita para ficar pública, quem protege os dados são as regras que o `schema.sql` criou.

## Parte 5. Publicar o app

1. No repositório, **Settings**, **Pages**.
2. Em **Build and deployment**, escolha **Deploy from a branch**, branch **main**, pasta **/ (root)** e salve.
3. Em 1 a 2 minutos o endereço aparece no topo, no formato `https://SEU-USUARIO.github.io/Rei-da-Faxina/`.
4. De volta ao Supabase, **Authentication**, **URL Configuration**, e coloque esse endereço em **Site URL**.

## Parte 6. Primeiro acesso

1. Abra o endereço do app, toque em **INICIAR** e em **Criar meu cadastro**.
2. **Faça o seu cadastro primeiro, com o e-mail do administrador** (Parte 2). Faça isso antes de passar o link para qualquer pessoa. O admin não precisa de código.
3. Entre em **Ajustes**, **Tarefas da casa**, escolha as tarefas que valem e ajuste os pontos.
4. Copie o **código da casa** (tela Início ou Ajustes, Participantes) e mande para os jogadores.
5. Cada jogador abre o app, toca em INICIAR, **Criar meu cadastro**, e informa nome, personagem, e-mail, senha e o código da casa. O limite é 4 jogadores.

## Parte 7. Instalar como app

- **Android (Chrome):** abra o endereço, toque em **Instalar app** na tela inicial do jogo (ou menu de três pontos, **Instalar app**).
- **iPhone (Safari):** botão Compartilhar, **Adicionar à Tela de Início**.
- **Computador (Chrome ou Edge):** ícone de instalar na barra de endereço.

Quer um arquivo APK de verdade? Em **pwabuilder.com**, cole o endereço do app e use **Package for stores**, **Android**. Ele gera o pacote para instalar ou publicar na Play Store.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| "Não foi possível carregar o Supabase" | `url` ou chave erradas no `config.js`, ou sem internet. |
| "Código da casa inválido" | Peça o código atual ao admin (ele pode trocar em Ajustes). |
| "O jogo já tem 4 jogadores" | Limite do jogo. O admin pode desativar alguém em Ajustes, Participantes. |
| "Invalid login credentials" | E-mail ou senha incorretos. Redefina em Authentication, Users, no Supabase. |
| Fotos não enviam | O `schema.sql` não rodou até o fim. Rode de novo (em um projeto novo, para evitar tabelas duplicadas). |
| App parou depois de dias sem uso | Projetos gratuitos podem ser pausados por inatividade. No painel do Supabase, clique em **Restore project**. |
| App não atualiza no celular | Feche e abra de novo o app. O navegador baixa a versão nova. |

## Limites

- Atualização entre aparelhos a cada 20 segundos, ou na hora após cada ação.
- Backup: **Database**, **Backups** no painel, ou exporte as tabelas.
- Sem `url` e chave no `config.js`, o app roda em modo local (dados só no aparelho).

Documentação oficial das chaves: https://supabase.com/docs/guides/getting-started/api-keys

## Reinício geral e tarefas fixas (1º de novembro de 2026)

Rode `supabase/reinicio.sql` uma vez no SQL Editor. Ele adiciona a frequência "Dias da semana" e a data de início do jogo, apaga o andamento (tarefas, pontos, moedas, histórico, bichinhos e períodos, mantendo contas, loja e tabela de pontos), abre o período 01/11 a 30/11 e cadastra as tarefas fixas de Davi, Camila e Vinicius. Antes de 1º de novembro nenhuma tarefa é gerada e o app mostra o aviso de início. Se um nome de perfil não for encontrado, o script para sem alterar nada e lista os nomes cadastrados.

## Comprovação sem foto

Rode `supabase/comprovacao.sql` uma vez no SQL Editor. O administrador escolhe o modo em Ajustes, no bloco "Jogo e premiação": só foto, foto ou "fiz, sem foto" (outra pessoa confirma, padrão) ou sem foto na confiança (vale na hora).
