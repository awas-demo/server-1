#!/bin/bash

# Deployment script for Server application
# This script builds and deploys the Docker image to AWS ECS

set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REPOSITORY="server-1"
ECS_CLUSTER="server-cluster"
ECS_SERVICE="server-service"
IMAGE_TAG="${1:-latest}"

echo "🚀 Starting deployment for Server application..."
echo "Region: $AWS_REGION"
echo "Image Tag: $IMAGE_TAG"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Get ECR repository URI
echo "📦 Getting ECR repository information..."
ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)
echo "✅ ECR Repository URI: $ECR_URI"

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $ECR_URI | cut -d'/' -f1)

# Build Docker image
echo "🔨 Building Docker image..."
docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_URI:$IMAGE_TAG

# Push image to ECR
echo "📤 Pushing image to ECR..."
docker push $ECR_URI:$IMAGE_TAG

# Update ECS service to use new image
echo "🔄 Updating ECS service..."
TASK_DEFINITION_ARN=$(aws ecs describe-task-definition --task-definition server-task-definition --region $AWS_REGION --query 'taskDefinition.taskDefinitionArn' --output text)

# Create new task definition with updated image
NEW_TASK_DEF=$(aws ecs describe-task-definition --task-definition server-task-definition --region $AWS_REGION --query 'taskDefinition' --output json | jq --arg IMAGE "$ECR_URI:$IMAGE_TAG" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')

echo "$NEW_TASK_DEF" > /tmp/new-task-definition.json

# Register new task definition
echo "📋 Registering new task definition..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file:///tmp/new-task-definition.json --region $AWS_REGION --query 'taskDefinition.taskDefinitionArn' --output text)

rm -f /tmp/new-task-definition.json

echo "✅ New task definition: $NEW_TASK_DEF_ARN"

# Update the service
echo "🚀 Updating ECS service with new task definition..."
aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $ECS_SERVICE \
    --task-definition $NEW_TASK_DEF_ARN \
    --region $AWS_REGION > /dev/null

echo "✅ ECS service update initiated"

# Wait for deployment to complete
echo "⏳ Waiting for deployment to complete..."
aws ecs wait services-stable --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION

# Get service status
SERVICE_STATUS=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].deployments[0].status' --output text)
RUNNING_COUNT=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].runningCount' --output text)
DESIRED_COUNT=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].desiredCount' --output text)

# Get Load Balancer DNS name
LB_ARN=$(aws elbv2 describe-load-balancers --names server-lb --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
if [ "$LB_ARN" != "None" ]; then
    LB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text --region $AWS_REGION)
fi

echo ""
echo "🎉 Deployment complete!"
echo "📋 Summary:"
echo "   • Image: $ECR_URI:$IMAGE_TAG"
echo "   • Task Definition: $NEW_TASK_DEF_ARN"
echo "   • Service Status: $SERVICE_STATUS"
echo "   • Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"
if [ "$LB_ARN" != "None" ]; then
    echo "   • Application URL: http://$LB_DNS"
    echo ""
    echo "🔍 Health check:"
    echo "   curl http://$LB_DNS/health"
fi
echo ""
echo "📝 To monitor the application:"
echo "   aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
echo "   aws logs tail /ecs/server-task-definition --follow --region $AWS_REGION"