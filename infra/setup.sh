#!/bin/bash

# AWS Infrastructure Setup Script for Server Application
# This script is idempotent and safe to run multiple times

set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REPOSITORY="server-1"
ECS_CLUSTER="server-cluster"
ECS_SERVICE="server-service"
ECS_TASK_DEFINITION="server-task-definition"
VPC_NAME="server-vpc"
SUBNET_NAME="server-subnet"
SECURITY_GROUP_NAME="server-sg"
LOAD_BALANCER_NAME="server-lb"
TARGET_GROUP_NAME="server-tg"

echo "🚀 Setting up AWS infrastructure for Server application..."
echo "Region: $AWS_REGION"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Create ECR repository
echo "📦 Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION > /dev/null 2>&1 || \
aws ecr create-repository \
    --repository-name $ECR_REPOSITORY \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256

echo "✅ ECR repository created/exists: $ECR_REPOSITORY"

# Get ECR login command
echo "🔐 Getting ECR login token..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text | cut -d'/' -f1)

# Create VPC if it doesn't exist
echo "🌐 Setting up VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$VPC_ID" = "None" ] || [ "$VPC_ID" = "null" ]; then
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
        --query 'Vpc.VpcId' \
        --output text)
    
    # Enable DNS hostnames
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $AWS_REGION
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support --region $AWS_REGION
fi

echo "✅ VPC ID: $VPC_ID"

# Create Internet Gateway
echo "🌐 Setting up Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$IGW_ID" = "None" ] || [ "$IGW_ID" = "null" ]; then
    IGW_ID=$(aws ec2 create-internet-gateway \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)
    
    aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
fi

echo "✅ Internet Gateway ID: $IGW_ID"

# Get availability zones
AZ1=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[1].ZoneName' --output text)

# Create public subnets
echo "🌐 Setting up subnets..."
SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_NAME-1" --query 'Subnets[0].SubnetId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$SUBNET1_ID" = "None" ] || [ "$SUBNET1_ID" = "null" ]; then
    SUBNET1_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 10.0.1.0/24 \
        --availability-zone $AZ1 \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME-1}]" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET1_ID --map-public-ip-on-launch --region $AWS_REGION
fi

SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_NAME-2" --query 'Subnets[0].SubnetId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$SUBNET2_ID" = "None" ] || [ "$SUBNET2_ID" = "null" ]; then
    SUBNET2_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 10.0.2.0/24 \
        --availability-zone $AZ2 \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME-2}]" \
        --query 'Subnet.SubnetId' \
        --output text)
    
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET2_ID --map-public-ip-on-launch --region $AWS_REGION
fi

echo "✅ Subnet 1 ID: $SUBNET1_ID"
echo "✅ Subnet 2 ID: $SUBNET2_ID"

# Create route table and associate with subnets
echo "🛣️ Setting up routing..."
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$VPC_NAME-rt" --query 'RouteTables[0].RouteTableId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$ROUTE_TABLE_ID" = "None" ] || [ "$ROUTE_TABLE_ID" = "null" ]; then
    ROUTE_TABLE_ID=$(aws ec2 create-route-table \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-rt}]" \
        --query 'RouteTable.RouteTableId' \
        --output text)
    
    # Add route to internet gateway
    aws ec2 create-route \
        --route-table-id $ROUTE_TABLE_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $IGW_ID \
        --region $AWS_REGION
    
    # Associate with subnets
    aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION
    aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION
fi

echo "✅ Route Table ID: $ROUTE_TABLE_ID"

# Create security group
echo "🔒 Setting up security group..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ "$SG_ID" = "null" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP_NAME \
        --description "Security group for Server application" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$SECURITY_GROUP_NAME}]" \
        --query 'GroupId' \
        --output text)
    
    # Add inbound rules
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 3000 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
fi

echo "✅ Security Group ID: $SG_ID"

# Create ECS cluster
echo "🚀 Setting up ECS cluster..."
aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION > /dev/null 2>&1 || \
aws ecs create-cluster \
    --cluster-name $ECS_CLUSTER \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --region $AWS_REGION

echo "✅ ECS Cluster created/exists: $ECS_CLUSTER"

# Create execution role for ECS tasks
echo "👤 Setting up IAM roles..."
EXECUTION_ROLE_NAME="ecsTaskExecutionRole"
EXECUTION_ROLE_ARN=$(aws iam get-role --role-name $EXECUTION_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "None")

if [ "$EXECUTION_ROLE_ARN" = "None" ]; then
    # Create trust policy document
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    EXECUTION_ROLE_ARN=$(aws iam create-role \
        --role-name $EXECUTION_ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --query 'Role.Arn' \
        --output text)
    
    aws iam attach-role-policy \
        --role-name $EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    
    rm trust-policy.json
fi

echo "✅ Execution Role ARN: $EXECUTION_ROLE_ARN"

# Create task definition
echo "📋 Setting up ECS task definition..."
ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)

cat > task-definition.json <<EOF
{
  "family": "$ECS_TASK_DEFINITION",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "server",
      "image": "$ECR_REPOSITORY_URI:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/$ECS_TASK_DEFINITION",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        }
      ]
    }
  ]
}
EOF

# Create CloudWatch log group
aws logs create-log-group --log-group-name "/ecs/$ECS_TASK_DEFINITION" --region $AWS_REGION 2>/dev/null || echo "Log group already exists"

# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region $AWS_REGION

rm task-definition.json

echo "✅ Task definition registered: $ECS_TASK_DEFINITION"

# Create ECS service
echo "🛠️ Setting up ECS service..."
aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION > /dev/null 2>&1 || \
aws ecs create-service \
    --cluster $ECS_CLUSTER \
    --service-name $ECS_SERVICE \
    --task-definition $ECS_TASK_DEFINITION \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET1_ID,$SUBNET2_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $AWS_REGION

echo "✅ ECS Service created/exists: $ECS_SERVICE"

echo ""
echo "🎉 Infrastructure setup complete!"
echo ""
echo "📝 Summary:"
echo "   ECR Repository: $ECR_REPOSITORY_URI"
echo "   VPC ID: $VPC_ID"
echo "   Subnet 1 ID: $SUBNET1_ID"
echo "   Subnet 2 ID: $SUBNET2_ID"
echo "   Security Group ID: $SG_ID"
echo "   ECS Cluster: $ECS_CLUSTER"
echo "   ECS Service: $ECS_SERVICE"
echo ""
echo "🚀 Next steps:"
echo "   1. Build and push your Docker image:"
echo "      docker build -t $ECR_REPOSITORY_URI:latest ."
echo "      docker push $ECR_REPOSITORY_URI:latest"
echo ""
echo "   2. Update the ECS service to deploy your image:"
echo "      aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment --region $AWS_REGION"
echo ""
echo "   3. Check service status:"
echo "      aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"