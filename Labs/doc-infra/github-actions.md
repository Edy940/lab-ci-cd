
Abaixo uma explicação  de cada **step** desse **GitHub Actions** para deploy de infraestrutura com **Terraform**:

1. Configuração Geral

-   O workflow é acionado quando há um **push** na branch `infra`.
-   Define variáveis de ambiente como a versão do Terraform (`TF_VERSION`), versão do TFLint (`TF_LINT_VERSION`), se a infraestrutura será destruída (`DESTROY`), e o ambiente (`ENVIRONMENT`).

```yaml
on:
  push:
    branches:
      - infra
env:
  TF_VERSION: 1.10.5
  TF_LINT_VERSION: v0.52.0
  DESTROY: false
  ENVIRONMENT: prod
``` 

---

2. Execução do Job `terraform`

-   O job **"Deploy Infra"** roda em uma máquina **Ubuntu-latest** e usa o diretório `infra`.

```yaml
jobs:
  terraform:
    name: 'Deploy Infra'
    runs-on: ubuntu-latest
```

3. Checkout do código

Baixa o código do repositório para a máquina runner.

```yaml
- name: Checkout
  uses: actions/checkout@v4
```

---

4. Configuração das credenciais AWS

Autentica na **AWS** usando as credenciais armazenadas nos `secrets`.

```yaml
- name: AWS | Configure credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}
    aws-region: ${{ secrets.AWS_REGION }}
```

---

5. Geração automática de documentação com Terraform-docs

Gera a documentação do código Terraform e atualiza o `README.md`.

```yaml
- name: Terraform-docs | Generate documentation
  uses: terraform-docs/gh-actions@v1.3.0
  with:
    working-dir: ./infra
    output-file: README.md
    output-method: inject
    git-push: "true"
```

---

6. Verificação da versão do Terraform

Verifica se o arquivo `versions.tf` especifica a versão do Terraform, caso contrário, usa a versão padrão definida no workflow.

```yaml
- name: Terraform | Check required version
  run: |
    if [ -f versions.tf ];
    then
	  echo "TF_VERSION=$(grep required_version versions.tf | sed 's/"//g' | awk '{ print $3 }')" >> $GITHUB_ENV
    else
      echo "Not set required_version in versions.tf, using default version in variable TF_VERSION in file .github/workflows/infra.yml"
      echo "TF_VERSION="${{ env.TF_VERSION }}"" >> $GITHUB_ENV
    fi
```

---

7. Instalação do Terraform

Baixa e instala a versão correta do Terraform.

```yaml
- name: Terraform | Setup
  uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: ${{ env.TF_VERSION }}
``` 

---

8. Exibir versão do Terraform

Mostra a versão instalada.

```yaml
- name: Terraform | Show version
  run: terraform --version
```

---

9. Configuração do Backend S3

Configura o **backend S3** para armazenar o **state file** do Terraform.

```yaml
- name: Terraform | Set up statefile S3 Bucket for Backend
  run: |
      echo "terraform {
        backend \"s3\" {
          bucket = \"${{ secrets.AWS_ACCOUNT_ID }}-tfstate\"
          key = \"${{ secrets.AWS_ACCOUNT_ID }}/"${{ env.ENVIRONMENT }}.tfvars"\"
          region = \"${{ secrets.AWS_REGION }}\"
        }
      }" >> provider.tf
      cat provider.tf
```

---

10. Inicialização do Terraform

Baixa os módulos e configura o **backend remoto**.

```yaml
- name: Terraform | Initialize backend
  run: terraform init
```

---

11. Formatação do código

Aplica o formato correto nos arquivos Terraform.

```yaml
- name: Terraform | Format code
  run: terraform fmt
```

---

12. Validação da sintaxe do código

Verifica se o código Terraform tem erros de sintaxe.

```yaml
- name: Terraform | Check Syntax IaC Code
  run: terraform validate
```

---

13. Configuração do Cache para TFLint

Usa cache para evitar downloads repetitivos dos plugins do **TFLint**.

```yaml
- name: TFlint | Cache plugin directory
  uses: actions/cache@v4
  with:
    path: ~/.tflint.d/plugins
    key: ${{ matrix.os }}-tflint-${{ hashFiles('.tflint.hcl') }}
```

---

14. Instalação do TFLint

Instala o **TFLint**, uma ferramenta de linting para Terraform.

```yaml
- name: TFlint | Setup TFLint
  uses: terraform-linters/setup-tflint@v4
  with:
    tflint_version: ${{ env.TF_LINT_VERSION }}
```

---

15. Exibir versão do TFLint

Mostra a versão instalada.

```yaml
- name: TFlint | Show version
  run: tflint --version
```

---

16. Inicialização do TFLint

Inicializa o TFLint e baixa os plugins necessários.

```yaml
- name: TFlint | Init TFLint
  run: tflint --init
  env:
    GITHUB_TOKEN: ${{ github.token }}
```

---

17. Execução do TFLint

Executa o **TFLint** para encontrar problemas de configuração no código Terraform.

```yaml
- name: TFlint | Run TFLint
  run: tflint -f compact
```

---

18. Verificação de segurança com TFSec

Roda o **TFSec** para analisar vulnerabilidades na infraestrutura.

```yaml
- name: TFSec | Security Checks
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    soft_fail: true
```

---

19. Execução do `terraform plan`

Gera um **plano de execução** (`tfplan.binary`), mostrando as mudanças que serão aplicadas.

```yaml
- name: Terraform | Plan
  run: terraform plan -out tfplan.binary
```

---

19. Converter `terraform plan` para JSON

Converte o plano de execução para **JSON**, útil para automações e auditorias.

```yaml
- name: Terraform | Show to json file
  run: terraform show -json tfplan.binary > plan.json
```

---

20. Destruição da Infraestrutura (se ativado)

Se `DESTROY` estiver configurado como `true`, o Terraform **destrói** todos os recursos.

```yaml
- name: Terraform Destroy
  if: env.DESTROY == 'true'
  run: terraform destroy -auto-approve -input=false
```

---

21. Aplicação do Terraform

Se `DESTROY` for `false`, o Terraform **aplica as mudanças** automaticamente.

```yaml
- name: Terraform Creating and Update
  if: env.DESTROY != 'true'
  run: terraform apply -auto-approve -input=false
```

---

## **📌 Resumo**

Este **workflow** realiza os seguintes passos:
✅ Faz checkout do código.  
✅ Configura credenciais AWS.  
✅ Gera documentação automática com **terraform-docs**.  
✅ Instala e configura **Terraform** e **TFLint**.  
✅ Formata e valida o código Terraform.  
✅ Executa **TFLint** para linting e **TFSec** para segurança.  
✅ Gera e converte o **terraform plan** para JSON.  
✅ Aplica ou destrói a infraestrutura baseado na variável `DESTROY`.