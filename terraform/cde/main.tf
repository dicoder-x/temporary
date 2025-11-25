provider "aws" {
  region = "eu-west-2"
}

# ───────────────────────────────────────────────
# Use existing Lambda (do NOT recreate it)
# ───────────────────────────────────────────────
data "aws_lambda_function" "cde-test-scheduler-lambda" {
  function_name = "goalposting-scheduler-lambda"
}

# Existing execution role (created inside Lambda console)
data "aws_iam_role" "cde-test-scheduler-lambda-exec-role" {
  name = "goalposting-scheduler-lambda-exec-role"
}

# ───────────────────────────────────────────────
# Add missing permissions onto the *existing* role
# ───────────────────────────────────────────────

# CloudWatch Logs already exists, but safe to attach
resource "aws_iam_role_policy_attachment" "cde-test-scheduler-lambda-basic" {
  role       = data.aws_iam_role.cde-test-scheduler-lambda-exec-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to manage EventBridge Scheduler schedules
resource "aws_iam_role_policy" "cde-test-scheduler-lambda-scheduler-access" {
  name = "cde-test-scheduler-lambda-scheduler-access"
  role = data.aws_iam_role.cde-test-scheduler-lambda-exec-role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "scheduler:CreateSchedule",
        "scheduler:DeleteSchedule",
        "scheduler:UpdateSchedule",
        "scheduler:GetSchedule"
      ],
      Resource = "*"
    }]
  })
}

# ───────────────────────────────────────────────
# EventBridge (CloudWatch Events) Bus
# ───────────────────────────────────────────────
resource "aws_cloudwatch_event_bus" "cde-test-scheduler-bus" {
  name = "cde-test-scheduler-bus"
}

# Rule triggered by ECS/dashboard
resource "aws_cloudwatch_event_rule" "cde-test-scheduler-ecs-rule" {
  name           = "cde-test-scheduler-ecs-rule"
  event_bus_name = aws_cloudwatch_event_bus.cde-test-scheduler-bus.name

  event_pattern = jsonencode({
    source        = ["cde-test.dashboard"]
    "detail-type" = ["create-scheduler"]
  })
}

# Target → Lambda
resource "aws_cloudwatch_event_target" "cde-test-scheduler-ecs-target" {
  rule           = aws_cloudwatch_event_rule.cde-test-scheduler-ecs-rule.name
  event_bus_name = aws_cloudwatch_event_bus.cde-test-scheduler-bus.name
  arn            = data.aws_lambda_function.cde-test-scheduler-lambda.arn
}

# Allow EventBridge to invoke Lambda (MUST HAVE UNIQUE STATEMENT ID!)
resource "aws_lambda_permission" "cde-test-scheduler-eventbridge-permission" {
  statement_id  = "TFAllowEventBridgeInvokeScheduler"   # FIXED
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.cde-test-scheduler-lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cde-test-scheduler-ecs-rule.arn
}

# ───────────────────────────────────────────────
# Daily EventBridge Scheduler Trigger
# ───────────────────────────────────────────────
resource "aws_scheduler_schedule" "cde-test-scheduler-daily" {
  name        = "cde-test-scheduler-daily-trigger"
  description = "Daily automatic trigger for Lambda"

  schedule_expression = "cron(0 23 * * ? *)" # UTC 23:00

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = data.aws_lambda_function.cde-test-scheduler-lambda.arn
    role_arn = data.aws_iam_role.cde-test-scheduler-lambda-exec-role.arn
    input    = jsonencode({ source = "daily-trigger" })
  }
}
