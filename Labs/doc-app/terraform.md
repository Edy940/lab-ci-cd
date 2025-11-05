### Entendendo o código do Terraform

1. Os blocos `data` do terraform é para recuperar os dados de algum recurso já criado na cloud.

- Obtém informações sobre um Target Group já existente chamado app-prod-tg.
- O Target Group é usado para rotear requisições para os containers no ECS.

```hcl
data "aws_security_groups" "this" {
  filter {
    name   = "tag:Name"
    values = ["app-prod-sg"]
  }
}
```

2. Busca informações sobre um Security Group chamado app-prod-sg

- O Security Group define as regras de tráfego de entrada e saída para os containers.

```hcl
data "aws_security_groups" "this" {
  filter {
    name   = "tag:Name"
    values = ["app-prod-sg"]
  }
}
```

3. Obtém detalhes sobre um Load Balancer chamado app-prod-nlb, definido pela variável lb_name.


```hcl
data "aws_lb" "this" {
  name = var.lb_name
}
```

4. Cria o serviço ECS (aws_ecs_service)

- Cria um serviço ECS chamado `app-service`.
- Usa a Task Definition chamada `ci-cd-app`.
- O serviço será executado no cluster definido em `var.cluster_name`.
- O número desejado de instâncias é definido em `var.desired_count`.
- O **FARGATE** é usado como launch type (sem necessidade de gerenciar servidores EC2).

Define a configuração de rede:
- Usa as subnets definidas na variável `var.subnets_id`.
- Usa os security groups buscados pelo `data.aws_security_groups.this`.
- Atribui um IP público aos containers.

Define a configuração de load balancer
- Associa o load balancer ao serviço ECS.
- O tráfego será direcionado ao container `ci-cd-app` na porta `8000`.

```hcl
resource "aws_ecs_service" "this" {
  name            = "app-service"
  task_definition = "ci-cd-app"
  cluster         = var.cluster_name
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  availability_zone_rebalancing = "ENABLED"

  network_configuration {
    subnets          = var.subnets_id
    security_groups  = data.aws_security_groups.this.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.this.arn
    container_name   = "ci-cd-app"
    container_port   = 8000
  }
}
```

5. CloudWatch Log Group (`aws_cloudwatch_log_group`)

- Cria um grupo de logs no CloudWatch para armazenar logs do serviço ECS.
- Define um período de retenção de 7 dias.

```hcl
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/ci-cd-app"
  retention_in_days = 7
}
```

6. Blocos output

- Exibe a URL do Load Balancer no final da execução do Terraform.

```hcl
output "nlb_dns_name" {
  value = format("http://%s", data.aws_lb.this.dns_name)
}
```

7. Bloco variable (Variáveis do Terraform)

- Define o nome do Cluster ECS.

```hcl
variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
  default     = "app-prod-cluster"
}
```

- Define quantas tasks (containers) devem rodar simultaneamente.

```hcl
variable "desired_count" {
  description = "desired tasks"
  type        = number
  default     = 3
}
```

- Lista de subnets onde os containers serão executados.

```hcl
variable "lb_name" {
  description = "Load Balancer Name"
  type        = string
  default     = "app-prod-nlb"
}
```

- Define o nome do Load Balancer.

```hcl
variable "lb_name" {
  description = "Load Balancer Name"
  type        = string
  default     = "app-prod-nlb"
}
```

8. Bloco `terraform`

- Define a versão do Terraform e o provedor AWS.

```hcl
terraform {
  required_version = "1.10.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.86.0"
    }
  }
}
```

9. Arquivo `terraform.tfvars`

```hcl
subnets_id = [
  "subnet-0fbf2767834e01e3c",
  "subnet-0803c20d0114bae14",
  "subnet-06bf008b57618c9c8"
]
```

10. Arquivo `ecs-task-definition.json`

Esse JSON define a task definition para o ECS.

- Configuração do container

```JSON
"containerDefinitions": [
    {
        "name": "ci-cd-app",
        "image": "gersontpc/ci-cd-app:v1.0.0",
        "cpu": 0,
```

- Define um container chamado `ci-cd-app`.
- Usa a imagem `gersontpc/ci-cd-app:v1.0.0`.
- Mapeamento de portas

```JSON
        "portMappings": [
            {
                "name": "port-access-8080",
                "containerPort": 8000,
                "hostPort": 8000,
                "protocol": "tcp",
                "appProtocol": "http"
            }
        ],
```

- O container usa a porta 8000 e aceita conexões HTTP.
- Configuração de logs

```JSON
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "/ecs/ci-cd-app",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
```

- Envia logs para o AWS CloudWatch no grupo /ecs/ci-cd-app.
- Configurações do Health Check.

```JSON
        "healthCheck": {
            "command": ["CMD-SHELL", "curl -f http://0.0.0.0:8000 || exit 1"],
            "interval": 15,
            "timeout": 5,
            "retries": 3,
            "startPeriod": 20
        }
```

- Realiza um health check verificando se a aplicação responde na porta 8000.
- Configuração da Task

```JSON
"family": "ci-cd-app",
"networkMode": "awsvpc",
"cpu": "512",
"memory": "1024",
"requiresCompatibilities": ["FARGATE"]
```

- Define a task como ci-cd-app.
- Usa 512 CPU e 1024MB de RAM.
- Utiliza o Fargate.

## **📌 Resumo**

✅ **Cria service do ecs**  
✅ **Cria uma task definition** com os parametros da app.  
✅ **Associa a service no Load Balancer** Para a aplicação ser acessada pelo dns do load balancer.  
