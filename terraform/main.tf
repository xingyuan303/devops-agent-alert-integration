terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# ── SNS Topic ────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# ── Secrets Manager ──────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "feishu_bot" {
  name = "${var.project_name}/feishu-bot"
}

resource "aws_secretsmanager_secret_version" "feishu_bot" {
  secret_id = aws_secretsmanager_secret.feishu_bot.id
  secret_string = jsonencode({
    FEISHU_APP_ID     = var.feishu_app_id
    FEISHU_APP_SECRET = var.feishu_app_secret
    DEVOPS_AGENT_SPACE_ID = var.devops_agent_space_id
  })
}

resource "aws_secretsmanager_secret" "github_token" {
  name = "${var.project_name}/github-token"
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}

# ── IAM Role for Lambdas ─────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.feishu_bot.arn, aws_secretsmanager_secret.github_token.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["aidevops:*"]
        Resource = "*"
      }
    ]
  })
}

# ── Lambda: feishu-notifier ──────────────────────────────────────────────────

data "archive_file" "feishu_notifier" {
  type        = "zip"
  source_file = "${path.module}/../lambda/feishu_notifier.py"
  output_path = "${path.module}/.build/feishu_notifier.zip"
}

resource "aws_lambda_function" "feishu_notifier" {
  function_name    = "${var.project_name}-feishu-notifier"
  role             = aws_iam_role.lambda_role.arn
  handler          = "feishu_notifier.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.feishu_notifier.output_path
  source_code_hash = data.archive_file.feishu_notifier.output_base64sha256

  environment {
    variables = {
      FEISHU_BOT_SECRET    = aws_secretsmanager_secret.feishu_bot.name
      FEISHU_CHAT_ID       = var.feishu_chat_id
      GITHUB_TOKEN_SECRET  = aws_secretsmanager_secret.github_token.arn
      GITHUB_REPO          = var.github_tickets_repo
    }
  }
}

resource "aws_sns_topic_subscription" "feishu_notifier" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.feishu_notifier.arn
}

resource "aws_lambda_permission" "sns_invoke_feishu" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.feishu_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# ── Lambda: investigation-notifier ───────────────────────────────────────────
# NOTE: This Lambda requires a custom boto3 with DevOps Agent service model.
# Build the deployment package using: cd lambda && ./build.sh
# Then upload to S3 and reference here.

resource "aws_lambda_function" "investigation_notifier" {
  function_name = "${var.project_name}-investigation-notifier"
  role          = aws_iam_role.lambda_role.arn
  handler       = "investigation_notifier.handler"
  runtime       = "python3.12"
  timeout       = 60
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = var.investigation_notifier_s3_key

  environment {
    variables = {
      GITHUB_TOKEN_SECRET  = aws_secretsmanager_secret.github_token.arn
      GITHUB_TICKETS_REPO  = var.github_tickets_repo
      DEVOPS_AGENT_SPACE_ID = var.devops_agent_space_id
      DEVOPS_AGENT_REGION  = var.region
      FEISHU_BOT_SECRET    = aws_secretsmanager_secret.feishu_bot.name
      FEISHU_CHAT_ID       = var.feishu_chat_id
    }
  }
}

# ── EventBridge Rule ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "devops_agent_events" {
  name = "${var.project_name}-investigation-events"
  event_pattern = jsonencode({
    source      = ["aws.aidevops"]
    detail-type = [
      "Investigation Created",
      "Investigation In Progress",
      "Investigation Completed",
      "Investigation Failed",
      "Investigation Timed Out",
      "Investigation Cancelled",
      "Investigation Pending Triage",
      "Investigation Linked"
    ]
  })
}

resource "aws_cloudwatch_event_target" "investigation_notifier" {
  rule = aws_cloudwatch_event_rule.devops_agent_events.name
  arn  = aws_lambda_function.investigation_notifier.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.investigation_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.devops_agent_events.arn
}
