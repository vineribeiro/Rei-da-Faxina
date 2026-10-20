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

## Identidade visual (assets 16 bits)

- Tela de título em formato de diorama: parede de pedra, piso de mármore, tapete real, trono, estante, banners, Rei Theron animado, inimigos do bestiário e HUD de corações e raios.
- Painel do Rei na tela inicial: sprite animado, balão de fala, XP em raios, sequência de dias em corações e coroa que evolui com o nível.
- Chefão do dia com 4 estados (parado, ataque, dano, derrotado) conforme as missões que faltam.
- Ícones de itens (vassoura, balde, spray, mop, esponja), moeda e coroas recortados das folhas em `img/`; folhas CSS em `ui.css`.

## Faxinho (bichinho estilo Tamagotchi)

- Cada jogador choca um ovo misterioso (10 animais, 3 raridades) e cuida dele com as moedas ganhas nas tarefas.
- Sente fome, sede, tédio, frio, calor, sono, sujeira, carência e doença. O tempo passa de verdade, mesmo com o app fechado.
- Ciclo de vida de 62 dias em 6 fases; quem cuida bem evolui para a forma radiante. Ao fim ele vira estrela e deixa um ovo com mais chance de raridade.
- Loja do Faxinho (casinha, bola, caminha, enfeites) e Álbum de Faxinhos.
- Avisos: ligue em Faxinho, Avisos. Chegam com o app aberto ou instalado e ativo em segundo plano. Aviso com o app totalmente fechado exige um servidor de push (Edge Function + chaves VAPID), que não está incluído.
- **Supabase:** rode `supabase/pets.sql` uma vez no SQL Editor (instalações novas já recebem pelo `schema.sql`). Sem isso a aba mostra um aviso, e o resto do app funciona normalmente.
