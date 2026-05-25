variable "region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "devops-agent-integration"
}

# ── DevOps Agent ─────────────────────────────────────────────────────────────

variable "devops_agent_space_id" {
  description = "DevOps Agent Space ID (from AWS Console)"
  type        = string
}

# ── Feishu ───────────────────────────────────────────────────────────────────

variable "feishu_app_id" {
  description = "Feishu App ID (from Feishu Open Platform)"
  type        = string
}

variable "feishu_app_secret" {
  description = "Feishu App Secret"
  type        = string
  sensitive   = true
}

variable "feishu_chat_id" {
  description = "Feishu group chat ID (oc_xxx format)"
  type        = string
}

# ── GitHub ───────────────────────────────────────────────────────────────────

variable "github_tickets_repo" {
  description = "GitHub repo for tickets (format: org/repo-name)"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token (needs repo scope)"
  type        = string
  sensitive   = true
}

# ── Lambda Deployment ────────────────────────────────────────────────────────

variable "lambda_s3_bucket" {
  description = "S3 bucket for Lambda deployment packages"
  type        = string
}

variable "investigation_notifier_s3_key" {
  description = "S3 key for investigation-notifier zip (contains custom boto3 with DevOps Agent SDK)"
  type        = string
  default     = "lambda/investigation_notifier.zip"
}
