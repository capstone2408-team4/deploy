#!/bin/bash

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
    "PROVIDENCE_ROOT_USERNAME"
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

# Store ALL configuration in SSM
echo "Storing configuration securely..."

# Core configuration
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/api-port" --value "$API_PORT" --type SecureString --overwrite

# Database configuration
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/postgres-user" --value "$POSTGRES_USER" --type SecureString --overwrite
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/postgres-password" --value "$POSTGRES_PASSWORD" --type SecureString --overwrite
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/postgres-db-name" --value "$POSTGRES_DB_NAME" --type SecureString --overwrite

# Redis configuration
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/redis-password" --value "$REDIS_PASSWORD" --type SecureString --overwrite

# Qdrant configuration
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/qdrant-api-key" --value "$QDRANT_API_KEY" --type SecureString --overwrite

# External APIs
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/openai-api-key" --value "$OPENAI_API_KEY" --type SecureString --overwrite
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/findip-api-key" --value "$FINDIP_API_KEY" --type SecureString --overwrite

# Authentication
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/jwt-secret" --value "$JWT_SECRET" --type SecureString --overwrite
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/root-project" --value "$PROVIDENCE_ROOT_PROJECT" --type SecureString --overwrite
aws ssm put-parameter --name "/providence/${ENVIRONMENT}/root-password" --value "$PROVIDENCE_ROOT_PASSWORD" --type SecureString --overwrite

# Generate self-signed certificate
echo "Generating self-signed certificate..."
CERT_DIR="$(mktemp -d)"
DOMAIN="*.${ENVIRONMENT}.providence.local"

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/private.key" \
  -out "${CERT_DIR}/certificate.crt" \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName = DNS:${DOMAIN}"

# Store cert and key in SSM
aws ssm put-parameter \
  --name "/providence/${ENVIRONMENT}/ssl-certificate" \
  --type SecureString \
  --value "$(cat ${CERT_DIR}/certificate.crt)" \
  --overwrite

aws ssm put-parameter \
  --name "/providence/${ENVIRONMENT}/ssl-private-key" \
  --type SecureString \
  --value "$(cat ${CERT_DIR}/private.key)" \
  --overwrite

# Clean up
rm -rf "${CERT_DIR}"

# Deploy infrastructure (now just needs Environment)
echo "Deploying Providence infrastructure..."
aws cloudformation deploy \
    --template-file providence-infrastructure.yaml \
    --stack-name "providence-${ENVIRONMENT}" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
        Environment="$ENVIRONMENT"

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