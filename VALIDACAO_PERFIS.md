# Validação de Pessoal e Empresa

## Verificações locais

- **124 testes Flutter passaram** no projeto instalado a partir do pacote.
- **17 verificações SQL passaram** no PostgreSQL local via PGlite.
- `flutter analyze`: nenhum problema encontrado.
- Compilação web concluída e navegação conferida no Chromium em 360 pixels:
  login, troca de perfil, limites separados, edição do nome empresarial e
  restauração da seleção após recarregar. As respostas do Supabase foram
  simuladas no navegador, sem usar contas ou dados reais.
- Suíte completa de testes Flutter, incluindo os fluxos anteriores de contas,
  lançamentos, edição da descrição, limites mensais e relatórios.
- Testes dos perfis: troca em um toque, seleção confirmada pelo servidor,
  persistência ao reabrir, edição do nome empresarial e falhas de conexão.
- Dados e limites separados por usuário, perfil e mês; respostas atrasadas
  da conta ou perfil anterior são descartadas.
- Avisos financeiros atuais e enfileirados são removidos ao trocar o perfil
  ou a conta autenticada.
- Cabeçalho em 320 e 360 pixels com texto ampliado; editor com teclado aberto.
- Testes do SDK usando servidor HTTP local para conferir filtros, payloads,
  sessão e rejeição de respostas de outro usuário ou perfil.
- Migração SQL executada repetidamente em PostgreSQL local via PGlite:
  preservação integral dos valores, datas e descrições anteriores; perfis de
  novos usuários; RLS; chaves compostas; seleção e nome preservados.
- Instalação do ZIP em cópia do projeto e preservação da configuração do
  Supabase, do formulário de adição e das fontes dos valores financeiros.

Nenhum lançamento, usuário ou limite real foi criado ou alterado durante
essas verificações. A migração no projeto Supabase real é executada por você
no SQL Editor conforme `PERFIS.md`.

## Conferência após instalar e executar o SQL

1. Abra Pessoal e confirme seus valores e limite anteriores.
2. Troque para Empresa e confirme que começa sem lançamentos ou limite.
3. Adicione uma despesa em Empresa e defina o limite daquele mês.
4. Troque entre os perfis e confira os valores de Início, Relatórios e
   Lançamentos. O limite de um perfil deve continuar diferente do outro.
5. Em Empresa, abra Perfil e edite o nome do negócio.
6. Recarregue a página e confirme o nome e a seleção restaurados.
7. Entre em outra conta e confira que ela recebe apenas os próprios perfis.

Uma consulta com falha deve mostrar erro, sem se apresentar como um perfil
vazio. Uma troca que falha mantém a seleção anterior.
