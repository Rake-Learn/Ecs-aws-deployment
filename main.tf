provider "aws" {
  region = "us-east-1"
}

# Fetch SSM Parameters for network and IAM configuration
data "aws_ssm_parameter" "subnet_id_1" {
  name = "/my-vpc/public-subnet-id-1"
}

data "aws_ssm_parameter" "subnet_id_2" {
  name = "/my-vpc/public-subnet-id-2"
}

data "aws_ssm_parameter" "security_group_id" {
  name = "/my-vpc/security-group-id"
}

data "aws_ssm_parameter" "ecs_task_execution_role_arn" {
  name = "/my-vpc/ecs_task_execution_role_arn"
}

# Fetch the ECR Image URI from SSM
data "aws_ssm_parameter" "ecr_image_uri" {
  name = "/myapp/ecr/image_uri"
}

# Optional Lambda Invoke ECS Role ARN
# data "aws_ssm_parameter" "lambda_invoke_ecs_role_arn" {
#   name = "/my-vpc/lambda_invoke_ecs_role_arn"
# }

# ECS Cluster
# tfsec:ignore:aws-ecs-enable-container-insight
resource "aws_ecs_cluster" "my_cluster" {
  name = var.ecs_cluster_name
}

# Store ECS Cluster ARN in SSM
resource "aws_ssm_parameter" "ecs_cluster_arn" {
  name  = "/myapp/ecs/cluster_arn"
  type  = "String"
  value = aws_ecs_cluster.my_cluster.arn
}

# ECS Task Definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = "my_task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_ssm_parameter.ecs_task_execution_role_arn.value

  container_definitions = jsonencode([{
    name      = "my-app"
    image     = data.aws_ssm_parameter.ecr_image_uri.value  # Pulling the image URI from SSM
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

# Store ECS Task Definition ARN in SSM
resource "aws_ssm_parameter" "ecs_task_definition_arn" {
  name  = "/myapp/ecs/task_definition_arn"
  type  = "String"
  value = aws_ecs_task_definition.my_task.arn
}

# ECS Service
resource "aws_ecs_service" "my_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [data.aws_ssm_parameter.subnet_id_1.value, data.aws_ssm_parameter.subnet_id_2.value]
    security_groups = [data.aws_ssm_parameter.security_group_id.value]
    assign_public_ip = true
  }
}
