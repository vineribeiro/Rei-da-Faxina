# Rei da Faxina

App gamificado de tarefas domésticas: ranking mensal, comprovação por foto, aprovação entre moradores, roleta, conquistas e loja de recompensas.

## Como usar
Abra o `index.html` no navegador, ou ative o GitHub Pages (Settings, Pages, branch `main`, pasta raiz).
Na primeira abertura, siga a configuração inicial. Cada participante tem o próprio PIN.

## Dados (versão atual)
Tudo fica no navegador e no aparelho (localStorage e IndexedDB), sem sincronização entre moradores.
Use Ajustes, Dados para copiar um backup. O PIN protege o acesso dentro do app, mas não impede alterações por quem tem acesso técnico ao aparelho.

## Próximo passo: Supabase
`supabase-schema.sql` traz tabelas, RLS, funções atômicas (aprovação, ajuste, estorno, resgate) e o bucket de fotos.
Falta no app trocar `Adapter` e `A.*` por chamadas ao Supabase, e no servidor implementar encerramento do mês, recorrências, penalidades e conquistas.
Com o Supabase, o login individual passa a ser feito pelo Supabase Auth.

## Instalar como app (PWA)
Com o GitHub Pages ativo, abra o endereço do site no Chrome do celular e use o menu, "Instalar app" (ou "Adicionar à tela inicial"). No computador, o ícone de instalar aparece na barra de endereço. O app abre em tela cheia e funciona offline.
