# Correções da auditoria

Esta versão corrige o salvamento de estado arbitrário do Faxinho, a limpeza de caches de outros aplicativos, recuperação de senha, redesenho de formulários, foco nos modais, sincronização repetitiva e uploads sem vínculo. Preserva a identidade retrô e usa texto de formulário mais legível. O aviso de início da competição passa a ser um banner.

## Publicação

O frontend depende das novas funções SQL. **Aplicar o SQL antes de publicar esta versão.** Não execute `schema.sql` nem `reinicio.sql` em um jogo existente: não são scripts de atualização.

1. No projeto usado pelo `config.js` (`spzpbjzmyczbkeyjimdl`), executar **somente** `supabase/audit-upgrade.sql` no SQL Editor. O arquivo é transacional e reaplicável; não apaga tarefas, pontos, moedas, fotos, contas ou pets. Bloqueia o endpoint antigo `pet_save` e instala `pet_action`, `sync_versions` e a reconciliação de uploads.
2. Em Authentication → URL Configuration, confirmar Site URL e Redirect URLs com `https://vineribeiro.github.io/Rei-da-Faxina/`. Conferir a configuração de envio de e-mails. O frontend envia links de recuperação para esse caminho.
3. Publicar o frontend deste PR pelo fluxo normal do GitHub Pages. Atualizar os aplicativos já abertos para carregar a nova versão do service worker. Durante a troca, clientes antigos recebem uma mensagem para atualizar ao tentar cuidar do Faxinho.
4. Verificar a recuperação usando uma conta de teste e testar duas sessões reais (aprovação simultânea, perda de conexão e troca de dispositivo). Os testes locais não enviam e-mail e não acessam o banco de produção.

A conexão Supabase disponível durante a implementação não tinha acesso ao projeto `spzpbjzmyczbkeyjimdl`. Portanto, as alterações SQL **não foram aplicadas no banco ativo**, e a configuração de redirect/e-mail ainda precisa ser conferida ali.

## O que mudou

- **Faxinho:** ações e preços definidos no servidor, relógio em America/Sao_Paulo, validação de inventário, saldo, espera entre cuidados e prazo de ressurreição. Pedidos têm chave de idempotência; uma resposta perdida pode ser reconciliada sem cobrança duplicada. O servidor mantém o histórico e o pet já existente. As funções auxiliares ficam em schema privado.
- **Sincronização:** uma consulta pequena informa as versões das tabelas; só as tabelas alteradas são baixadas novamente. A carga inicial ainda lê o histórico completo para preservar ranking, conquistas e totais existentes. É uma melhoria de tráfego ocioso, não uma promessa de carregamento inicial constante com histórico ilimitado.
- **Formulários:** atualizações em segundo plano aguardam rascunhos e modais. O foco é contido no modal e retorna ao acionador ao fechar.
- **Fotos:** upload pendente é anotado antes do envio. A reconciliação usa o mesmo bloqueio SQL que o registro da comprovação, protegendo contra exclusão quando a resposta da operação confirmada se perde. Arquivos só podem ser removidos quando foram abandonados pelo próprio usuário e não têm vínculo. A fila é retomada ao entrar novamente; uploads recentes de outra aba são preservados por 10 minutos. A limpeza depende de retorno ao aplicativo e não remove automaticamente arquivos órfãos anteriores a esta versão.
- **Cache:** remove apenas versões reconhecidas do Rei da Faxina; ignora caminhos de outros projetos na mesma origem.
- **Acesso:** solicitação de recuperação, tela de nova senha, tratamento de link inválido/expirado e retorno ao login após atualização.

## Validação reproduzível

```sh
npm ci
npm test
```

A suíte usa jsdom para DOM e PGlite (PostgreSQL em WASM) com um esquema de teste de Auth/Storage. Cobre permissões, preservação de dados, repetição da atualização SQL, custos, pedidos repetidos, cooldown, ciclo do pet, fotos, versões, recuperação de senha, rascunhos, teclado e cache.

Não substitui testes em celular real, entrega efetiva de e-mails, configuração de RLS do projeto ativo ou concorrência em múltiplas conexões de produção. Executar os advisors do Supabase após aplicar o upgrade.
