provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "workflow_testing" {
  bucket  = "workflow_testing"
  force_destroy = true
  tags    = {
	Name  = "workflow_testing"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_versioning" "workflow_testing_versioning" {
  bucket = aws_s3_bucket.workflow_testing.id
  versioning_configuration {
    status = "Enabled" 
  }
}

resource "aws_s3_bucket_public_access_block" "workflow_testing_block_public" {
  bucket = aws_s3_bucket.workflow_testing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "workflow_testing_encryption" {
  bucket = aws_s3_bucket.workflow_testing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


data "aws_iam_policy_document" "deny_insecure_transport" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.workflow_testing.arn,
      "${aws_s3_bucket.workflow_testing.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "workflow_testing_policy" {
  bucket = aws_s3_bucket.workflow_testing.id
  policy = data.aws_iam_policy_document.deny_insecure_transport.json
}

output "workflow_testing_bucket_name" {
  value = aws_s3_bucket.workflow_testing
}

output "workflow_testing_bucket_arn" {
  value = aws_s3_bucket.workflow_testing
}
