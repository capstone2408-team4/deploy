#!/bin/bash

# Disable AWS CLI pagination
# export AWS_PAGER=""

echo "Providence AWS Infrastructure Deployment"
echo "======================================="

# Verify AWS CLI installation and auth
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not installed. Visit: https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI not authenticated. Run: aws configure"
    exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "Error: No .env file found. Copy .env.example to .env and fill in values."
    exit 1
fi

# Load .env
source .env

# Required variables
required_vars=(
    "AWS_REGION"
    "ENVIRONMENT"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "POSTGRES_DB_NAME"
    "REDIS_PASSWORD"
    "QDRANT_API_KEY"
    "OPENAI_API_KEY"
    "FINDIP_API_KEY"
    "JWT_SECRET"
    "PROVIDENCE_ROOT_PROJECT"
    "PROVIDENCE_ROOT_PASSWORD"
    "API_PORT"
)

# Check for missing variables
missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Error: Missing required variables in .env:"
    printf '%s\n' "${missing_vars[@]}"
    exit 1
fi


# Store sensitive configuration in Secrets Manager
echo "Storing configuration secrets securely..."

# Database configuration
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/postgres-user" --secret-string "$POSTGRES_USER"  --force-overwrite-replica-secret
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/postgres-password" --secret-string "$POSTGRES_PASSWORD"  --force-overwrite-replica-secret
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/postgres-db-name" --secret-string "$POSTGRES_DB_NAME"  --force-overwrite-replica-secret

# Redis configuration
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/redis-password" --secret-string "$REDIS_PASSWORD"  --force-overwrite-replica-secret

# Qdrant configuration
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/qdrant-api-key" --secret-string "$QDRANT_API_KEY"  --force-overwrite-replica-secret

# External APIs
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/openai-api-key" --secret-string "$OPENAI_API_KEY"  --force-overwrite-replica-secret
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/findip-api-key" --secret-string "$FINDIP_API_KEY"  --force-overwrite-replica-secret

# Authentication
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/jwt-secret" --secret-string "$JWT_SECRET"  --force-overwrite-replica-secret
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/root-project" --secret-string "$PROVIDENCE_ROOT_PROJECT"  --force-overwrite-replica-secret
aws secretsmanager create-secret --region "${AWS_REGION}" --name "/providence/${ENVIRONMENT}/root-password" --secret-string "$PROVIDENCE_ROOT_PASSWORD"  --force-overwrite-replica-secret


# Generate and import self-signed certificate
echo "Generating and importing self-signed certificate..."
CERT_DIR="$(mktemp -d)"
DOMAIN="*.${ENVIRONMENT}.providence.local"

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${CERT_DIR}/private.key" \
    -out "${CERT_DIR}/certificate.crt" \
    -subj "/CN=${DOMAIN}" \
    -addext "subjectAltName = DNS:${DOMAIN}"

# Import to ACM and capture the ARN
CERT_ARN="$(aws acm import-certificate \
    --certificate fileb://"${CERT_DIR}/certificate.crt" \
    --private-key fileb://"${CERT_DIR}/private.key" \
    --region "${AWS_REGION}" \
    --output text)"

# Clean up
rm -rf "${CERT_DIR}"


# Deploy CodeBuild Infrastructure
echo "Deploying CodeBuild infrastructure stack..."
aws cloudformation deploy \
    --template-file codebuild-infrastructure.yaml \
    --stack-name "providence-${ENVIRONMENT}-codebuild-infra" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${AWS_REGION}" \
    --parameter-overrides \
        Environment="${ENVIRONMENT}"

if [ $? -ne 0 ]; then
    echo "❌ CodeBuild Infrastructure deployment failed"
    exit 1
fi

echo "✅ CodeBuild Infrastructure deployment successful!"


# Retrieve outputs from the codebuild infrastructure stack
ECR_URI=$(aws cloudformation describe-stacks \
    --stack-name "providence-${ENVIRONMENT}-codebuild-infra" \
    --region "${AWS_REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
    --output text)

CODEBUILD_PROJECT_NAME=$(aws cloudformation describe-stacks \
    --stack-name "providence-${ENVIRONMENT}-codebuild-infra" \
    --region "${AWS_REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='CodeBuildProjectName'].OutputValue" \
    --output text)

if [ -z "$ECR_URI" ] || [ -z "$CODEBUILD_PROJECT_NAME" ]; then
    echo "Error: Failed to retrieve outputs from codebuild infrastructure stack."
    exit 1
fi

echo "ECR Repository URI: $ECR_URI"
echo "CodeBuild Project Name: $CODEBUILD_PROJECT_NAME"


# Read the buildspec.yml
BUILDSPEC_CONTENT=$(cat buildspec.yml)

# Start CodeBuild project
echo "Starting CodeBuild project..."
BUILD_ID=$(aws codebuild start-build \
    --project-name "$CODEBUILD_PROJECT_NAME" \
    --region "${AWS_REGION}" \
    --buildspec-override "$BUILDSPEC_CONTENT" \
    --query 'build.id' \
    --output text)

if [ -z "$BUILD_ID" ]; then
    echo "Error: Failed to start CodeBuild project."
    exit 1
fi

# Wait for CodeBuild project to complete
echo "Waiting for CodeBuild project to complete..."
BUILD_STATUS=""
while [ "$BUILD_STATUS" != "SUCCEEDED" ] && [ "$BUILD_STATUS" != "FAILED" ]; do
    sleep 10
    BUILD_STATUS=$(aws codebuild batch-get-builds \
        --ids "$BUILD_ID" \
        --region "${AWS_REGION}" \
        --query 'builds[0].buildStatus' \
        --output text)
done

if [ "$BUILD_STATUS" == "FAILED" ]; then
    echo "Error: CodeBuild project failed."
    exit 1
fi

echo "CodeBuild project completed successfull!"


# Deploy Providence infrastructure
echo "Deploying Providence infrastructure stack..."
aws cloudformation deploy \
    --template-file providence-infrastructure.yaml \
    --stack-name "providence-${ENVIRONMENT}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${AWS_REGION}" \
    --parameter-overrides \
        Environment="${ENVIRONMENT}" \
        ApiPort="${API_PORT}" \
        # CertificateArn="${CERT_ARN}" \
        ImageURI="${ECR_URI}:latest" \
        PostgresUser="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/postgres-user}}" \
        PostgresPassword="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/postgres-password}}" \
        PostgresDbName="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/postgres-db-name}}" \
        RedisPassword="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/redis-password}}" \
        QdrantApiKey="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/qdrant-api-key}}" \
        OpenAiApiKey="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/openai-api-key}}" \
        FindIpApiKey="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/findip-api-key}}" \
        JwtSecret="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/jwt-secret}}" \
        ProvidenceRootProject="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/root-project}}" \
        ProvidenceRootPassword="{{resolve:secretsmanager:/providence/${ENVIRONMENT}/root-password}}" \

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    
    # Display outputs
    aws cloudformation describe-stacks \
        --stack-name "providence-${ENVIRONMENT}" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
else
    echo "❌ Deployment failed"
    exit 1
fi