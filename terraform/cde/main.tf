# REGION
provider "aws" {
  region = "eu-west-2"
}

# CLOUDWATCH LOG GROUP
resource "aws_cloudwatch_log_group" "a1234-test-ecs-log" {
  name              = "/ecs/a1234-test-streamlit-dashboard"
  retention_in_days = 7
}

# ECS CLUSTER
resource "aws_ecs_cluster" "a1234-test-ecs-cluster" {
  name = "a1234-test-ecs-cluster"
}

# IAM ASSUME ROLE
data "aws_iam_policy_document" "a1234-test-ecs-task-execution-assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# TASK EXECUTION ROLE
resource "aws_iam_role" "a1234-test-ecs-task-execution" {
  name               = "a1234-test-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.a1234-test-ecs-task-execution-assume.json
}

# EXECUTION ROLE POLICY ATTACHMENT
resource "aws_iam_role_policy_attachment" "a1234-test-ecs-execution-policy" {
  role       = aws_iam_role.a1234-test-ecs-task-execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# TASK ROLE (permissions for the container)
resource "aws_iam_role" "a1234-test-ecs-task-role" {
  name               = "a1234-test-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.a1234-test-ecs-task-execution-assume.json
}

# ATHENA + S3 + GLUE PERMISSIONS
data "aws_iam_policy_document" "a1234-test-ecs-task-athena" {
  statement {
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:ListQueryExecutions",
      "athena:StopQueryExecution"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.BUCKET_NAME}",
      "arn:aws:s3:::${var.BUCKET_NAME}/*"
    ]
  }
}

resource "aws_iam_role_policy" "a1234-test-ecs-task-lambda-scheduler-access" {
  name = "a1234-test-ecs-task-lambda-scheduler-access"
  role = aws_iam_role.a1234-test-ecs-task-role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = aws_lambda_function.a1234-test-scheduler-lambda.arn
      },

      {
        Effect = "Allow",
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule"
        ],
        Resource = "*"
      },

      # Allow ECS to provide the EventBridge Invoke Role to Scheduler
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = aws_iam_role.a1234-test-scheduler-eventbridge-invoke-role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "a1234-test-ecs-task-athena-policy" {
  name   = "a1234-test-ecs-task-athena"
  role   = aws_iam_role.a1234-test-ecs-task-role.id
  policy = data.aws_iam_policy_document.a1234-test-ecs-task-athena.json
}

# SECURITY GROUP
resource "aws_security_group" "a1234-test-ecs-tasks-sg" {
  name        = "a1234-test-ecs-tasks-sg"
  description = "Security group for ECS fargate tasks"
  vpc_id      = var.VPC_ID

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INBOUND RULE FOR STREAMLIT
resource "aws_security_group_rule" "ecs_inbound_http" {
  type              = "ingress"
  from_port         = 8501
  to_port           = 8501
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.a1234-test-ecs-tasks-sg.id
}

# TASK DEFINITION
resource "aws_ecs_task_definition" "a1234-test-streamlit-task" {
  family                   = "a1234-test-streamlit-dashboard"
  cpu                      = var.CPU
  memory                   = var.MEMORY_SIZE
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.a1234-test-ecs-task-execution.arn
  task_role_arn      = aws_iam_role.a1234-test-ecs-task-role.arn

  container_definitions = jsonencode([
    {
      name      = "a1234-test-streamlit-dashboard"
      image     = var.DASHBOARD_IMAGE_URI
      essential = true

      portMappings = [
        {
          containerPort = 8501
          hostPort      = 8501
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "GLUE_DB_NAME", value = var.GLUE_DB_NAME }
      ],

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.a1234-test-ecs-log.name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "a1234-test-ecs"
        }
      }
    }
  ])
}

# ECS SERVICE
resource "aws_ecs_service" "a1234-test-streamlit-service" {
  name            = "a1234-test-streamlit-dashboard-service"
  cluster         = aws_ecs_cluster.a1234-test-ecs-cluster.id
  task_definition = aws_ecs_task_definition.a1234-test-streamlit-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.SUBNET_IDs
    security_groups = [aws_security_group.a1234-test-ecs-tasks-sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

