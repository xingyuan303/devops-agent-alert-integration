#!/bin/bash
# Deploy investigation-notifier Lambda (requires S3 bucket for 16MB zip)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGION="${AWS_REGION:-us-east-1}"
FUNCTION_NAME="$(cd "$SCRIPT_DIR/terraform" && terraform output -raw investigation_notifier_function_name 2>/dev/null || echo "devops-agent-integration-investigation-notifier")"
S3_BUCKET="$(cd "$SCRIPT_DIR/terraform" && terraform output -raw lambda_s3_bucket 2>/dev/null || echo "")"
S3_KEY="lambda/investigation_notifier.zip"

if [ -z "$S3_BUCKET" ]; then
  echo "ERROR: S3_BUCKET not set. Either run 'terraform apply' first or set it manually:"
  echo "  S3_BUCKET=your-bucket ./deploy.sh"
  exit 1
fi

echo "==> Building package..."
cd "$SCRIPT_DIR/lambda"
bash build.sh

echo "==> Uploading to s3://$S3_BUCKET/$S3_KEY..."
aws s3 cp "$SCRIPT_DIR/lambda/investigation_notifier.zip" "s3://$S3_BUCKET/$S3_KEY" --region "$REGION"

echo "==> Deploying Lambda..."
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --s3-bucket "$S3_BUCKET" \
  --s3-key "$S3_KEY" \
  --region "$REGION" \
  --query '{FunctionName:FunctionName,LastModified:LastModified,CodeSize:CodeSize}' \
  --output table

echo "==> Done!"
