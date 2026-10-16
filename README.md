# Rei da Faxina

App gamificado de tarefas domésticas: ranking mensal, comprovação por foto, aprovação entre moradores, roleta, conquistas e loja de recompensas.

## Como usar
Abra o `index.html` no navegador, ou ative o GitHub Pages (Settings, Pages, branch `main`, pasta raiz).
Na primeira abertura, siga a configuração inicial. Cada participante tem o próprio PIN.

## Dados
- **Modo local** (`config.js` vazio): tudo no aparelho, sem sincronização. Perfil admin com PIN e jogadores com cadastro próprio.
- **Modo Supabase** (`config.js` preenchido): login por e-mail e senha, dados compartilhados entre todos, fotos em bucket privado. Guia completo em [SUPABASE.md](SUPABASE.md).

## Instalar como app (PWA)
Com o GitHub Pages ativo, abra o endereço do site no Chrome do celular e use o menu, "Instalar app" (ou "Adicionar à tela inicial"). No computador, o ícone de instalar aparece na barra de endereço. O app abre em tela cheia e funciona offline.
