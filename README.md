# Rei da Faxina

App gamificado de tarefas domésticas: ranking mensal, comprovação por foto, aprovação entre moradores, roleta, conquistas e loja de recompensas.

## Como usar
Abra o `index.html` no navegador, ou ative o GitHub Pages (Settings, Pages, branch `main`, pasta raiz).
Na primeira abertura, siga a configuração inicial. Cada participante entra com o próprio e-mail e senha.

## Identidade
Logo, paleta e personagens estão em `img/` e `icons/`. Na criação do cadastro e em Ajustes, Meu perfil, cada pessoa escolhe um personagem: Pequeno Rei, Rainha, Rei de Óculos ou um dos emojis.

## Tela inicial e app
O jogo abre numa tela com a coroa e o botão INICIAR. É um app instalável (PWA): botão "Instalar app" na tela inicial, atalho para Tarefas e funcionamento offline do visual.

## Visual e tarefas
- Visual 8 bits (fontes Press Start 2P e VT323, bordas retas, barras segmentadas), níveis (NV) e sons de chiptune (botão de som no topo).
- 39 tarefas já cadastradas: 8 diárias (5 a 10 pts), 13 semanais (10 a 25), 8 quinzenais (25 a 45) e 10 mensais (50 a 100).
- O admin escolhe quais valem em Ajustes, "Tarefas da casa": marca, desmarca e ajusta os pontos de cada uma.

## Dados
- **Modo local** (`config.js` vazio): tudo no aparelho, sem sincronização. O administrador cria o próprio e-mail e senha na configuração inicial; cada jogador faz o cadastro com e-mail e senha. Ninguém entra automático: sempre pede login.
- **Modo Supabase** (`config.js` preenchido): login por e-mail e senha, dados compartilhados entre todos, fotos em bucket privado. Guia completo em [SUPABASE.md](SUPABASE.md).

## Instalar como app (PWA)
Com o GitHub Pages ativo, abra o endereço do site no Chrome do celular e use o menu, "Instalar app" (ou "Adicionar à tela inicial"). No computador, o ícone de instalar aparece na barra de endereço. O app abre em tela cheia e funciona offline.

## Novidades de interface

- Barra de XP na tela inicial e animação de LEVEL UP.
- Quadro de missões com abas: Diárias, Semanais, Quinzenais, Mensais e Avulsas.
- Vibração no celular ao concluir, aprovar e subir de nível.
- Tutorial de 3 telas no primeiro acesso (dá para rever em Ajustes, Aparência).
- Contadores nos ícones do menu (ex.: "2 para aprovar").
- Temas Game Boy, Noturno e Alto contraste, e texto maior (Ajustes, Aparência).
- Telas de carregamento (esqueleto) enquanto o banco sincroniza.

## Identidade visual (folha "Rei da Faxina")

- Tela de título com o castelo isométrico e o slogan "Limpeza também é uma missão".
- Chefão do dia na tela inicial (Golem de Pó, Verme de Mofo, Aranha, Serpente de Graxa): a vida dele é a fatia de missões do mês ainda abertas.
- Ícones do arsenal real (vassoura, spray, mop) no tutorial e raio de XP na barra de nível.
