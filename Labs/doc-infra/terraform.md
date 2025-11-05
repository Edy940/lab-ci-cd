### Entendendo o código do Terraform

1. Criação do Cluster ECS

-   Cria um **Cluster ECS** com o nome que for preenchido na variável `var.cluster_name` e complementa com o `-cluster`, ficando da seguinte forma: app-pro
-   Habilita **Container Insights** para monitoramento.

```hcl
resource "aws_ecs_cluster" "this" {
  name = format("%s-cluster", var.cluster_name)

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

---

2. Cria um Network Load Balancer (NLB)

-   Cria um **Network Load Balancer (NLB)** chamado `var.cluster_name-nlb`.
-   Está associado às **subnets** informadas na variável `var.subnets_id`.
-   Usa o **grupo de segurança** `aws_security_group.allow_inbound`.
-   O tipo do **Load Balancer** é `network`, adequado para tráfego TCP/UDP de baixa latência.

```hcl
resource "aws_lb" "this" {
  name = format("%s-nlb", var.cluster_name)

  subnets            = var.subnets_id
  security_groups    = [aws_security_group.allow_inbound.id]
  load_balancer_type = "network"

  tags = {
    Name = format("%s-nlb", var.cluster_name)
  }
}
```

---

3. Criando um Listener para o NLB

-   Configura um **Listener** para escutar tráfego na **porta 80 (TCP)**.
-   Encaminha o tráfego para o **Target Group** (`aws_lb_target_group.this.arn`).

```
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
```


---

4. Criando um Target Group

-   Define um **Target Group** para encaminhar tráfego ao **ECS**.
-   Usa **porta 80 (TCP)**.
-   O **target_type** é `ip`, permitindo a associação de **tasks ECS** diretamente pelo endereço IP.

```hcl
resource "aws_lb_target_group" "this" {
  name        = format("%s-tg", var.cluster_name)
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  tags = {
    Name = format("%s-tg", var.cluster_name)
  }
}
```

---

5. Criando um Grupo de Segurança

-   Cria um **Security Group** para permitir **tráfego de entrada e saída**.
-   **Ingress:** Permite acesso na porta `8000/TCP` de qualquer IP (`0.0.0.0/0`).
-   **Egress:** Libera saída irrestrita para qualquer destino.

```hcl
resource "aws_security_group" "allow_inbound" {
  name        = format("%s-sg", var.cluster_name)
  vpc_id      = var.vpc_id
  description = "Allow inbound traffic"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = format("%s-sg", var.cluster_name)
  }
}
```

---

6. Definição de Variáveis

-   **`cluster_name`** → Nome base para os recursos (ECS Cluster, SG, NLB, etc.).
-   **`subnets_id`** → Lista de Subnets onde o Load Balancer será provisionado.
-   **`vpc_id`** → ID da **VPC** onde os recursos serão criados.

```hcl
variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
}

variable "subnets_id" {
  description = "Subnets IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
```

---

7. Configuração do Terraform

-   **`required_version`** → Define a versão do **Terraform** como `1.10.5`.
-   **`required_providers`** → Usa o provedor **AWS** na versão `~> 5.86.0`.

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

---

## **📌 Resumo**

✅ **Cria um ECS Cluster** com Performance Insights habilitado.  
✅ **Cria um Network Load Balancer (NLB)** para tráfego TCP.  
✅ **Configura um Listener** que encaminha tráfego ao Target Group.  
✅ **Define um Target Group** para rotear tráfego para instâncias ECS (Fargate).  
✅ **Cria um Security Group** permitindo tráfego na porta 8000/TCP.  
✅ **Usa variáveis** para personalizar os recursos.  
✅ **Especifica versões** do Terraform e do provedor AWS.