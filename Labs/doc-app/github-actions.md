### GitHub Actions Build/Deploy App

Este **GitHub Actions workflow** realiza o **build e deploy** de uma aplicação com **Docker**, **Python**, **Terraform**, e **Amazon ECS**. Ele foi configurado para ser disparado automaticamente em um **push** para a branch `main`.

---

#### 1. **Configuração Geral**

* **Nome do workflow:** `Deploy App`.
* **Disparo do workflow:** Quando houver um **push** na branch `main`.
* **Variáveis de ambiente global:**

  * `DESTROY`: Define se o Terraform deve destruir os recursos (`false` por padrão).
  * `TF_VERSION`: Versão do Terraform utilizada.
  * `IMAGE_NAME`: Nome da imagem Docker.
  * `ECS_SERVICE`: Nome do serviço ECS.
  * `ECS_CLUSTER`: Nome do cluster ECS.
  * `APP_VERSION`: Versão da aplicação.
  * `ENVIRONMENT`: Ambiente de deploy (`prod`).

```yaml
name: 'Deploy App'

on:
  push:
    branches:
      - main

env:
  DESTROY: false
  TF_VERSION: 1.10.5
  IMAGE_NAME: ci-cd-app
  ECS_SERVICE: app-service
  ECS_CLUSTER: app-prod-cluster
  ENVIRONMENT: prod
```

---

### 2. **Job: Build App**

O job **`Build`** é responsável por realizar o build da aplicação, criar a imagem Docker e realizar testes, além de empurrar a imagem para o Docker Hub.

#### 2.1 **Definição do Job `Build`**

* O job **`Build`** roda na máquina **`ubuntu-latest`**.
* Define que os comandos executados no shell utilizarão o `bash` dentro do diretório **`app`**.

```yaml
jobs:
  Build:
    name: 'Building app'
    runs-on: ubuntu-latest

    defaults:
      run:
        shell: bash
        working-directory: app
```

#### 2.2 **Checkout do Código**

* Realiza o **checkout** do código-fonte do repositório no runner.
* O `fetch-depth: 0` garante que **todo o histórico Git** seja baixado.

```yaml
  - name: Download do Repositório
    uses: actions/checkout@v4
    with:
      fetch-depth: 0
```

#### 2.3 **Configuração do Python**

* Configura o ambiente Python **versão 3.10** para rodar os testes.

```yaml
  - name: Setup Python
    uses: actions/setup-python@v4
    with:
      python-version: '3.10'
```

#### 2.4 **Instalação das Dependências**

* Instala o **Flask** para rodar a aplicação.

```yaml
  - name: Install Requirements
    run: pip install flask
```

#### 2.5 **Executando Testes Unitários**

* Roda os **testes unitários** com o **`unittest`**.

```yaml
  - name: Unit Test
    run: python -m unittest -v test
```

#### 2.6 **Login no Docker Hub**

* Faz login no **Docker Hub** utilizando credenciais secretas armazenadas.

```yaml
  - name: Login to Docker Hub
    uses: docker/login-action@v3
    with:
      username: ${{ secrets.DOCKERHUB_USERNAME }}
      password: ${{ secrets.DOCKERHUB_TOKEN }}
```

#### 2.7 **Construção da Imagem Docker**

* Habilita o **DOCKER\_BUILDKIT** para uma construção mais eficiente.
* Cria a **imagem Docker** com a tag definida (`IMAGE_NAME:TAG_APP`).

```yaml
  - name: Build an image from Dockerfile
    env:
      DOCKER_BUILDKIT: 1
    run: |
      docker build -t ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:${{ env.TAG_APP }} .
```

#### 2.8 **Escaneamento de Vulnerabilidades com Trivy**

* **Escaneia a imagem Docker** em busca de vulnerabilidades.
* Se encontrar vulnerabilidades **críticas**, o workflow **falha**.

```yaml
  - name: Run Trivy vulnerability scanner
    uses: aquasecurity/trivy-action@master
    with:
      image-ref: '${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:${{ env.TAG_APP }}'
      format: 'table'
      exit-code: '1'
      ignore-unfixed: true
      vuln-type: 'os,library'
      severity: 'CRITICAL'
```

#### 2.9 **Push da Imagem no Docker Hub**

* Faz o **push** da imagem para o **Docker Hub**.

```yaml
  - name: Push image
    run: |
      docker image push ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:${{ env.TAG_APP }}
```

---

### 3. **Job: Deploy App**

O job **`Deploy`** é responsável por realizar o deploy da aplicação no **Amazon ECS**. Ele só é executado após o job **`Build`** (`needs: Build`).

#### 3.1 **Definição do Job `Deploy`**

* O job **`Deploy`** roda na máquina **`ubuntu-latest`**.
* Usa a saída do job **`Build`** para passar a variável `image_tag`.

```yaml
  Deploy:
    name: 'Deploy App'
    runs-on: ubuntu-latest
    needs: Build
```

#### 3.2 **Checkout do Código**

* Realiza o **checkout** do código-fonte do repositório no runner.

```yaml
  - name: Download do Repositório
    uses: actions/checkout@v4
    with:
      fetch-depth: 0
```

#### 3.3 **Configuração de Credenciais AWS**

* Configura as credenciais para que o AWS CLI possa ser utilizado.

```yaml
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}
      aws-region: ${{ vars.AWS_REGION }}
```

#### 3.4 **Atualizar a Task Definition**

* Preenche a definição da task do ECS com a nova imagem gerada no `Build`.

```yaml
  - name: Fill in the new image ID in the Amazon ECS task definition
    id: task-def
    uses: aws-actions/amazon-ecs-render-task-definition@v1
    with:
      task-definition: ./app/deploy/ecs-task-definition.json
      container-name: ${{ env.IMAGE_NAME }}
      image: ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:${{ needs.Build.outputs.image_tag }}
```

#### 3.5 **Registrar a Task Definition**

* Registra a nova **task definition** no Amazon ECS.

```yaml
  - name: Register Task Definition
    id: task-definition
    uses: aws-actions/amazon-ecs-deploy-task-definition@v2
    with:
      task-definition: ${{ steps.task-def.outputs.task-definition }}
```

#### 3.6 **Configuração do Terraform**

* Inicializa e aplica as configurações do Terraform para o backend S3.

```yaml
  - name: Terraform | Setup
    uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: ${{ env.TF_VERSION }}
```

#### 3.7 **Terraform | Backend S3**

* Configura o **backend do Terraform** para armazenar o estado no S3.

```yaml
  - name: Terraform | Set up statefile S3 Bucket for Backend
    run: |
        echo "terraform {
          backend \"s3\" {
            bucket   = \"${{ secrets.AWS_ACCOUNT_ID }}-tfstate\"
            key      = \"app-${{ env.ENVIRONMENT }}.tfstate\"
            region   = \"${{ vars.AWS_REGION }}\"
          }
        }" >> provider.tf
        cat provider.tf
    working-directory: ./app/deploy
```

#### 3.8 **Inicialização do Terraform**

* **Inicializa o Terraform** e baixa os plugins necessários.

```yaml
  - name: Terraform | Initialize backend
    run: terraform init
    working-directory: ./app/deploy
```

#### 3.9 **Validar e Aplicar o Código Terraform**

* **Valida** a sintaxe do código Terraform e **aplica** as mudanças para criar ou destruir os recursos no ECS.

```yaml
  - name: Terraform | Check Syntax IaC Code
    run: terraform validate
    working-directory: ./app/deploy
```

#### 3.10 **Deploy no Amazon ECS**

* Realiza o **deploy** da nova versão da aplicação no **Amazon ECS**.

```yaml
  - name: Deploy App in Amazon ECS
    uses: aws-actions/amazon-ecs-deploy-task-definition@v2
    with:
      task-definition: ${{ steps.task-def.outputs.task-definition }}
      service: ${{ env.ECS_SERVICE }}
      cluster: ${{ env.ECS_CLUSTER }}
      wait-for-service-stability: true
```

---

## 📌 **Resumo**

Este workflow realiza as seguintes etapas:  
✅ **Build da aplicação** com **Docker**.  
✅ **Criação e push** da imagem no **Docker Hub**.  
✅ **Escaneamento de vulnerabilidades** com **Trivy**.  
✅ **Deploy automático** da aplicação no **Amazon ECS**.  
✅ Configuração e uso do **Terraform** para provisionamento de infraestrutura.  
🚀 **Deploy automático** da aplicação em produção.
