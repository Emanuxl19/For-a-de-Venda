# Força de Vendas (TOTVS Protheus ↔ MaxPedido)

Projeto em **AdvPL/Protheus** para integração via **REST API** entre o TOTVS ERP e o MaxPedido (força de vendas), com rotinas de **envio (Upload)** e **recebimento (Download)**.

## Estrutura

- `JOBFVAUT.prw`: autenticação na API e obtenção do bearer token.
- `JOBFV_ENV.prw`: orquestrador (execução sequencial das rotinas de `Upload/`).
- `BAFATPFV.PRW`: interface/execução seletiva de rotinas de `Upload/`.
- `BAFATJFV.prw`: orquestrador (execução sequencial das rotinas de `Download/`).
- `JOBFV_REC.prw`: interface/execução seletiva de rotinas de `Download/` (quando existir no projeto).
- `Upload/`: rotinas `JOBFVE##.prw` (Protheus → MaxPedido).
- `Download/`: rotinas `JOBFVR##.prw` (MaxPedido → Protheus).

## Configuração (credenciais e URLs)

Por segurança, o repositório usa **placeholders** nos fontes:

```advpl
Local cURI      := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
Local cUsrLogin := "LOGIN_DE_USUARIO"       // Configurar com seu login da API
Local cUsrSenha := "SENHA_DO_USUARIO"       // Configurar com sua senha da API
```

Também existe um modelo de variáveis em `.env.example` (não versionar `.env`):

1. Copie `.env.example` para `.env`
2. Preencha com os valores reais

Observação: por padrão, **AdvPL não carrega `.env` automaticamente**. Use o `.env` como referência local/operacional (ou adapte o código/ambiente para ler variáveis de ambiente, se desejado).

## Padrões importantes

- **Não comitar dados sensíveis** (URLs privadas, logins, senhas, CNPJ real, nomes de clientes/empresas, IPs internos).
- Tabelas Protheus no código usam **alias genérico** (ex.: `SC5`, `SA1`, `SF1`), sem sufixo de empresa/filial.

## Como executar (Protheus)

- Para enviar dados: execute `U_JOBFV_ENV()` (lote) ou use a rotina/entrada configurada para `BAFATPFV`.
- Para receber dados: execute `U_BAFATJFV()` (lote) ou a rotina interativa correspondente (quando disponível).

## Git/GitHub

- `.env` é ignorado pelo Git (veja `.gitignore`).
- Fluxo básico:
  - `git add .`
  - `git commit -m "Initial commit"`
  - `git remote add origin https://github.com/<org>/<repo>.git`
  - `git push -u origin main`

