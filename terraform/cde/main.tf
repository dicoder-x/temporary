# REGION
provider "aws" {
  region = "eu-west-2"
}

# CLOUDWATCH LOG GROUP
resource "aws_cloudwatch_log_group" "goalposting-ecs-log" {
  name              = "/ecs/goalposting-streamlit-dashboard"
  retention_in_days = 7
}

# ECS CLUSTER
resource "aws_ecs_cluster" "goalposting-ecs-cluster" {
  name = "goalposting-ecs-cluster"
}

# IAM ASSUME ROLE
data "aws_iam_policy_document" "goalposting-ecs-task-execution-assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# TASK EXECUTION ROLE
resource "aws_iam_role" "goalposting-ecs-task-execution" {
  name               = "goalposting-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.goalposting-ecs-task-execution-assume.json
}

# EXECUTION ROLE POLICY ATTACHMENT
resource "aws_iam_role_policy_attachment" "goalposting-ecs-execution-policy" {
  role       = aws_iam_role.goalposting-ecs-task-execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# TASK ROLE (permissions for the container)
resource "aws_iam_role" "goalposting-ecs-task-role" {
  name               = "goalposting-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.goalposting-ecs-task-execution-assume.json
}

# ATHENA + S3 + GLUE PERMISSIONS
data "aws_iam_policy_document" "goalposting-ecs-task-athena" {
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

resource "aws_iam_role_policy" "goalposting-ecs-task-athena-policy" {
  name   = "goalposting-ecs-task-athena"
  role   = aws_iam_role.goalposting-ecs-task-role.id
  policy = data.aws_iam_policy_document.goalposting-ecs-task-athena.json
}

# SECURITY GROUP
resource "aws_security_group" "goalposting-ecs-tasks-sg" {
  name        = "goalposting-ecs-tasks-sg"
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
  security_group_id = aws_security_group.goalposting-ecs-tasks-sg.id
}

# TASK DEFINITION
resource "aws_ecs_task_definition" "goalposting-streamlit-task" {
  family                   = "goalposting-streamlit-dashboard"
  cpu                      = var.CPU
  memory                   = var.MEMORY_SIZE
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.goalposting-ecs-task-execution.arn
  task_role_arn      = aws_iam_role.goalposting-ecs-task-role.arn

  container_definitions = jsonencode([
    {
      name      = "goalposting-streamlit-dashboard"
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
          awslogs-group         = aws_cloudwatch_log_group.goalposting-ecs-log.name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "goalposting-ecs"
        }
      }
    }
  ])
}

# ECS SERVICE
resource "aws_ecs_service" "goalposting-streamlit-service" {
  name            = "goalposting-streamlit-dashboard-service"
  cluster         = aws_ecs_cluster.goalposting-ecs-cluster.id
  task_definition = aws_ecs_task_definition.goalposting-streamlit-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.SUBNET_IDs
    security_groups = [aws_security_group.goalposting-ecs-tasks-sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_iam_role_policy" "goalposting-ecs-task-lambda-scheduler-access" {
  name = "goalposting-ecs-task-lambda-scheduler-access"
  role = aws_iam_role.goalposting-ecs-task-role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = aws_lambda_function.goalposting-scheduler-lambda.arn
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
        Resource = aws_iam_role.goalposting-scheduler-eventbridge-invoke-role.arn
      }
    ]
  })
}
