#!/bin/bash
# Build the investigation-notifier Lambda package with custom boto3 (DevOps Agent SDK)
# Output: investigation_notifier.zip (~16MB)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/investigation_notifier"
OUTPUT="$SCRIPT_DIR/investigation_notifier.zip"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Installing dependencies..."
pip install --target "$BUILD_DIR" --quiet \
  'boto3>=1.43.0' \
  'botocore>=1.43.0'

echo "==> Copying Lambda handler..."
cp "$SCRIPT_DIR/investigation_notifier.py" "$BUILD_DIR/"

# Install DevOps Agent service model (not yet in official botocore)
# If you have a custom botocore with devops-agent model, install it instead:
#   pip install --target "$BUILD_DIR" --quiet /path/to/botocore-with-devops-agent.whl

echo "==> Packaging..."
cd "$BUILD_DIR"
zip -r "$OUTPUT" . -x "__pycache__/*" "*.dist-info/RECORD" > /dev/null

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "==> Done: $OUTPUT ($SIZE)"
echo ""
echo "Upload to S3:"
echo "  aws s3 cp $OUTPUT s3://<your-bucket>/lambda/investigation_notifier.zip"
