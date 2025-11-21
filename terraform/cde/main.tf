resource "aws_glue_catalog_database" "cde-testing-db" {
  name = var.GLUE_DB_NAME
}

resource "aws_iam_role" "cde-testing-glue-crawler-role" {
  name = "cde-testing-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cde-testing-glue-crawler-policy" {
  name = "cde-testing-glue-crawler-policy"
  role = aws_iam_role.cde-testing-glue-crawler-role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.BUCKET_NAME}",
          "arn:aws:s3:::${var.BUCKET_NAME}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_crawler" "cde-testing-crawler" {
  name         = var.CRAWLER_NAME
  database_name = aws_glue_catalog_database.cde-testing-db.name
  role         = aws_iam_role.cde-testing-glue-crawler-role.arn

  s3_target {
    path = "s3://${var.BUCKET_NAME}"
    }
  # Optional schedule, can be run on-demand by Lambda
  # schedule = "cron(* * * * ? *)"
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Tables = {}
    }
  })
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
}
