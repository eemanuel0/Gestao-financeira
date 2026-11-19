# Validação de Perfil, fotos e Caixa empresarial

As verificações usam dados locais ou respostas simuladas. Nenhuma conta,
foto, lançamento ou configuração do seu Supabase foi alterada por esses testes.

- **161 testes Flutter passaram** na cópia instalada a partir do pacote.
- `flutter analyze`: nenhum problema encontrado.
- Compilação web concluída e navegação conferida no Chromium em 320 e 360
  pixels, usando seleção real de arquivo pelo `image_picker` e respostas
  simuladas do Supabase: nome pessoal, contatos/CNPJ da empresa, upload,
  assinatura privada, remoção, recarregamento e faturamento calculado.
- Testes Flutter de contas, lançamentos, relatórios, limites e troca de perfil.
- Edição pessoal com nome confirmado e e-mail da conta preservado.
- Dados empresariais e CNPJ separados do perfil Pessoal.
- Foto e remoção confirmadas somente no perfil escolhido; troca de conta
  durante um envio não publica a foto na outra sessão.
- SDK real com servidor HTTP local para dados, autenticação e Storage:
  upload, assinatura, confirmação do caminho, falhas, limpeza e reconciliação.
- Imagens JPEG, PNG e WebP decodificáveis; rejeição de arquivos inválidos,
  MIME incompatível, excesso de tamanho e caminhos de outra conta/perfil.
- CNPJ numérico e alfanumérico, preservando zeros iniciais e validando os
  dígitos verificadores; ausência de CNPJ e contato continua válida.
- Categorias empresariais, salário como receita pessoal e salários da equipe
  como saída empresarial; histórico antigo preservado.
- Faturamento mensal soma vendas e serviços, com centavos exatos e filtros
  de conta, perfil e mês.
- **20 verificações SQL locais passaram**, cobrindo migração repetida,
  preservação dos registros, campos, categorias e privacidade das fotos.

A migração real deve ser executada por você no SQL Editor do Supabase,
conforme `PERFIL_FOTOS.md`. A instalação do ZIP no Codespace não altera o
banco nem cria automaticamente o bucket na nuvem.

Depois de instalar e executar a migração, confira no aplicativo:

1. Nome e e-mail corretos no perfil Pessoal.
2. Foto salva após recarregar e retorno às iniciais ao removê-la.
3. Dados e foto próprios no perfil Empresa.
4. Lançamentos e limites anteriores preservados em cada perfil.
5. Vendas/Serviços no faturamento e demais entradas apenas no saldo de caixa.
