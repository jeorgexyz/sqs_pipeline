#!/bin/bash
set -e

# AWS SQS Pipeline Setup Script
# This script creates the necessary AWS resources for the pipeline

echo "=== SQS Pipeline AWS Setup ==="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Get user input
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter S3 bucket name: " BUCKET_NAME
if [ -z "$BUCKET_NAME" ]; then
    echo "ERROR: Bucket name is required"
    exit 1
fi

read -p "Enter SQS queue name: " QUEUE_NAME
if [ -z "$QUEUE_NAME" ]; then
    echo "ERROR: Queue name is required"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Region: $AWS_REGION"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  SQS Queue: $QUEUE_NAME"
echo ""
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted"
    exit 0
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Create S3 bucket
echo ""
echo "Creating S3 bucket..."
if aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"; then
    echo "✓ S3 bucket created"
else
    echo "⚠ Bucket may already exist or error occurred"
fi

# Create SQS queue
echo ""
echo "Creating SQS queue..."
QUEUE_URL=$(aws sqs create-queue \
    --queue-name "$QUEUE_NAME" \
    --region "$AWS_REGION" \
    --query 'QueueUrl' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✓ SQS queue created"
    echo "  Queue URL: $QUEUE_URL"
else
    echo "⚠ Queue may already exist, getting URL..."
    QUEUE_URL=$(aws sqs get-queue-url \
        --queue-name "$QUEUE_NAME" \
        --region "$AWS_REGION" \
        --query 'QueueUrl' \
        --output text)
fi

# Get queue ARN
QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names QueueArn \
    --region "$AWS_REGION" \
    --query 'Attributes.QueueArn' \
    --output text)
echo "  Queue ARN: $QUEUE_ARN"

# Set SQS queue policy
echo ""
echo "Setting SQS queue policy..."
cat > /tmp/queue-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "SQS:SendMessage",
      "Resource": "$QUEUE_ARN",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:s3:::$BUCKET_NAME"
        }
      }
    }
  ]
}
EOF

aws sqs set-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attributes "Policy=$(cat /tmp/queue-policy.json | jq -c .)" \
    --region "$AWS_REGION"
echo "✓ Queue policy set"

# Configure S3 notification
echo ""
echo "Configuring S3 event notifications..."
cat > /tmp/notification.json <<EOF
{
  "QueueConfigurations": [
    {
      "QueueArn": "$QUEUE_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket "$BUCKET_NAME" \
    --notification-configuration file:///tmp/notification.json \
    --region "$AWS_REGION"
echo "✓ S3 notifications configured"

# Create .env file
echo ""
echo "Creating .env file..."
cat > .env <<EOF
# AWS Configuration
export AWS_REGION=$AWS_REGION
export AWS_ACCESS_KEY_ID=your_access_key_here
export AWS_SECRET_ACCESS_KEY=your_secret_key_here

# SQS Pipeline Configuration
export SQS_QUEUE_URL=$QUEUE_URL

# Usage:
# source .env
EOF
echo "✓ .env file created"

# Cleanup temp files
rm -f /tmp/queue-policy.json /tmp/notification.json

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit .env and add your AWS credentials"
echo "2. Run: source .env"
echo "3. Run: mix deps.get"
echo "4. Run: mix run --no-halt"
echo ""
echo "Test by uploading a file to S3:"
echo "  aws s3 cp test.txt s3://$BUCKET_NAME/"
echo ""
