# Perfil, fotos e Caixa da empresa

Esta atualização segue a referência visual da tela de Perfil: cartão com foto
ou iniciais, dados da conta, edição do perfil, menus e botão de sair.
Os dados vêm da sua conta e do perfil financeiro escolhido.

## O que funciona nesta etapa

- **Pessoal:** editar o nome, visualizar o e-mail da conta e colocar ou remover
  a foto. O e-mail permanece como o endereço usado no login.
- **Empresa:** editar nome fantasia, razão social, CNPJ opcional, e-mail de
  contato e telefone; colocar ou remover uma foto própria do negócio.
- **Conta** e **Editar perfil** abrem o formulário correspondente ao perfil
  ativo. **Ajuda** explica os recursos que já estão disponíveis.
- **Segurança** e **Preferências** ficam identificadas como **Em breve**,
  para receber as próximas funções de configurações.
- **Sair da conta** encerra a sessão deste dispositivo.

As fotos de Pessoal e Empresa são independentes. Elas ficam em armazenamento
privado no Supabase, vinculado à conta e ao perfil. São aceitas imagens JPEG,
PNG e WebP de até 5 MB. Cancelar a seleção mantém a foto anterior.
As iniciais são exibidas quando ainda não há foto ou ela não pode ser carregada.

A seleção usa `image_picker`, cuja adição foi autorizada nesta etapa.
O pacote mantém a configuração existente do Supabase.

## Categorias da empresa

O perfil Pessoal mantém suas categorias. No perfil Empresa, o formulário usa
**Entrada** e **Saída**:

- Entradas: Vendas, Serviços e Outros.
- Saídas: Fornecedores, Salários da equipe, Aluguel, Contas da empresa,
  Impostos, Transporte e Outros.

O painel empresarial mostra **Caixa da empresa**, **Saldo em caixa**,
**Entradas**, **Saídas** e **Faturamento no mês**. O faturamento mensal soma
apenas as entradas registradas como Vendas e Serviços no mês atual.
Outras entradas participam do saldo, sem serem somadas ao faturamento.
O histórico antigo mantém os valores, datas, descrições e categorias salvos.

Esta versão mantém um titular por conta. Ela não cria acessos compartilhados
de gerentes ou funcionários.

## 1. Instalar pelo terminal do Codespace

Pare o Flutter com `q` no terminal em que ele estiver executando.
Envie `financas_perfil_foto.zip` para a raiz do projeto, junto de `pubspec.yaml`.
Execute nessa raiz:

```bash
python3 -m zipfile -e financas_perfil_foto.zip .
bash financas_atualizado/instalar.sh
flutter pub get
```

O instalador faz backup dos arquivos substituídos em `backups_financas/`.
`config/supabase.json` não faz parte do pacote e é preservado.
O pacote inclui o código atual completo, os testes e os arquivos SQL para
evitar arquivos de código ausentes entre as atualizações anteriores.

## 2. Preparar o banco e as fotos

**Pasta:** `supabase/migrations/`  
**Novo arquivo:** `004_profile_details_and_business.sql`

No explorador do Codespace, abra esse arquivo, selecione todo o conteúdo e
copie. Ele também pode ser exibido pelo terminal:

```bash
cat supabase/migrations/004_profile_details_and_business.sql
```

Abra o SQL Editor do seu projeto:

https://supabase.com/dashboard/project/hoarqhhielhwxwoyatoy/sql/new

Cole o conteúdo completo e clique em **Run**. Ele adiciona os campos da
empresa, as categorias empresariais e o armazenamento privado das fotos,
sem alterar os valores do histórico.

As migrações 001, 002 e 003 precisam ter sido executadas anteriormente no
mesmo projeto. Se a troca Pessoal/Empresa já funciona, execute somente a nova
migração **004**. Se ainda falta a migração 003, execute-a antes da 004.
Não execute novamente uma migração antiga depois da 004; siga a ordem dos
arquivos ao configurar um projeto novo.

O instalador no Codespace não executa SQL na nuvem. Para que a foto e os
novos campos sejam salvos, esta etapa no SQL Editor precisa concluir sem erros.

## 3. Validar e abrir

```bash
dart format lib test
flutter analyze
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn --dart-define-from-file=config/supabase.json
```

Abra a porta 8080 na aba **Portas** do Codespace e atualize a página.

## Usar e conferir

1. Abra Perfil em Pessoal e edite o nome. Confira o mesmo e-mail da conta.
2. Toque no ícone de câmera para selecionar a foto. Recarregue a página para
   conferir que ela ficou salva. **Remover foto** volta às iniciais.
3. Troque para Empresa. Abra Perfil e cadastre os dados do negócio, deixando
   o CNPJ vazio se ainda não quiser informá-lo. A empresa pode ter outra foto.
4. Adicione uma saída empresarial em **Salários da equipe** e uma entrada
   em **Vendas**. Confira os valores no Caixa e no Relatório desse perfil.
5. Volte para Pessoal e confirme que os dados financeiros e a foto continuam
   separados dos dados da empresa.

O CNPJ é validado pelo formato e pelos dígitos verificadores; não é uma
consulta de existência ou situação cadastral na Receita Federal. O validador
aceita os formatos numérico e alfanumérico conforme o
[manual oficial de cálculo da Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj/manual-dv-cnpj.pdf).

Os nomes dos arquivos e as pastas estão separados em `ARQUIVOS_PERFIL_FOTOS.md`.
