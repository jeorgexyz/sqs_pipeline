#!/bin/bash
# Script to test the pipeline locally with LocalStack

echo "=== LocalStack Test Script ==="
echo ""

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null; then
    echo "ERROR: LocalStack is not running"
    echo "Start it with: docker-compose up -d localstack"
    exit 1
fi

echo "✓ LocalStack is running"

# Configuration
BUCKET_NAME="test-bucket"
QUEUE_NAME="test-queue"
ENDPOINT="http://localhost:4566"

# Create bucket
echo ""
echo "Creating S3 bucket..."
aws --endpoint-url=$ENDPOINT s3 mb s3://$BUCKET_NAME 2>/dev/null || echo "Bucket already exists"

# Create queue
echo "Creating SQS queue..."
QUEUE_URL=$(aws --endpoint-url=$ENDPOINT sqs create-queue \
    --queue-name $QUEUE_NAME \
    --query 'QueueUrl' \
    --output text 2>/dev/null)

if [ -z "$QUEUE_URL" ]; then
    QUEUE_URL=$(aws --endpoint-url=$ENDPOINT sqs get-queue-url \
        --queue-name $QUEUE_NAME \
        --query 'QueueUrl' \
        --output text)
fi
echo "Queue URL: $QUEUE_URL"

# Get queue ARN
QUEUE_ARN=$(aws --endpoint-url=$ENDPOINT sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text)
echo "Queue ARN: $QUEUE_ARN"

# Configure S3 notifications
echo ""
echo "Configuring S3 notifications..."
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

aws --endpoint-url=$ENDPOINT s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file:///tmp/notification.json

echo "✓ Configuration complete"

# Create test file
echo ""
echo "Creating test file..."
cat > /tmp/test-data.txt <<EOF
line 1
line 2
line 3
line 4
line 5
EOF

# Upload test file
echo "Uploading test file to S3..."
aws --endpoint-url=$ENDPOINT s3 cp /tmp/test-data.txt s3://$BUCKET_NAME/data/test-data.txt

echo ""
echo "✓ Test file uploaded"
echo ""
echo "The pipeline should now process the file."
echo "Check the logs and output/ directory for results."
echo ""
echo "To send more test files:"
echo "  aws --endpoint-url=$ENDPOINT s3 cp yourfile.txt s3://$BUCKET_NAME/data/"
echo ""
