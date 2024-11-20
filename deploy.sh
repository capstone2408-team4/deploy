#!/bin/bash

# Disable AWS CLI pagination
export AWS_PAGER=""

echo "Providence AWS Infrastructure Deployment"
echo "======================================="

# Verify AWS CLI installation and auth
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI not installed. Visit: https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS CLI not authenticated. Run: aws configure"
    exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "❌ Error: No .env file found. Copy .env.example to .env and fill in values."
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
    echo "❌ Error: Missing required variables in .env:"
    printf '%s\n' "${missing_vars[@]}"
    exit 1
fi


# Store sensitive configuration in Secrets Manager
echo "Storing configuration secrets securely..."

secret_names=(
    "postgres-user|$POSTGRES_USER"
    "postgres-password|$POSTGRES_PASSWORD"
    "postgres-db-name|$POSTGRES_DB_NAME"
    "redis-password|$REDIS_PASSWORD"
    "qdrant-api-key|$QDRANT_API_KEY"
    "openai-api-key|$OPENAI_API_KEY"
    "findip-api-key|$FINDIP_API_KEY"
    "jwt-secret|$JWT_SECRET"
    "root-project|$PROVIDENCE_ROOT_PROJECT"
    "root-password|$PROVIDENCE_ROOT_PASSWORD"
)

# Loop through each secret
for entry in "${secret_names[@]}"; do
    key="${entry%%|*}"
    value="${entry#*|}"
    secret_name="/providence/${ENVIRONMENT}/${key}"
    
    # Check if the secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" > /dev/null 2>&1; then
        echo "Updating secret: $secret_name"
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$value"
    else
        echo "Creating secret: $secret_name"
        aws secretsmanager create-secret \
            --region "$AWS_REGION" \
            --name "$secret_name" \
            --secret-string "$value"
    fi
done

# Generate and import self-signed certificate
echo ""
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


# Function to monitor stack resources
monitor_stack() {
    local stack_name="$1"

    while true; do
        # Capture the resources state
        resources=$(aws cloudformation describe-stack-resources \
            --stack-name "$stack_name" \
            --region "${AWS_REGION}" \
            --query "StackResources[?ResourceStatus=='CREATE_IN_PROGRESS' || ResourceStatus=='UPDATE_IN_PROGRESS' || ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED'].[Timestamp,LogicalResourceId,ResourceStatus]" \
            --output table \
            --color on \
            --no-paginate \
            --no-cli-pager)

        # Output the resources state
        echo ""
        echo "$resources"

        # Spin for 15
        start_time=$(date +%s)
        end_time=$((start_time + 15))
        
        i=0
        sp="-\|/"
        while [ "$(date +%s)" -lt "$end_time" ]; do
            printf "\b%c" "${sp:i%4:1}"
            sleep 0.1
            ((i++))
        done
        printf "\r" # Clear spinner

        # Count the output lines
        lines=$(( $(echo "$resources" | wc -l) + 1))

        # Clear the resources output for next poll
        for ((j=0; j<lines; j++)); do
            tput el    # Clear the line
            tput cuu1  # Move up one line
            tput el    # Clear the line
        done

        # Capture the status of the entire deployment
        status=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "${AWS_REGION}" \
            --query 'Stacks[0].StackStatus' \
            --output text 2>&1)
        
        # Break if finished or failed or stack does not exist
        if [[ $status =~ .*COMPLETE$ || $status =~ .*FAILED$ || $status == *"does not exist"* ]]; then
            break
        fi
        
    done
}

# Deploy Providence infrastructure
echo ""
echo "Deploying Providence infrastructure stack..."
echo "Only limited progress output will be shown here. Please view your AWS CloudFormation console for complete information!"

# Run deployment in background
aws cloudformation deploy \
    --template-file providence-infrastructure.yaml \
    --stack-name "providence-${ENVIRONMENT}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${AWS_REGION}" \
    --parameter-overrides \
        Environment="${ENVIRONMENT}" \
        ApiPort="${API_PORT}" \
        CertificateArn="${CERT_ARN}" \
        PostgresUser='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/postgres-user}}' \
        PostgresPassword='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/postgres-password}}' \
        PostgresDbName='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/postgres-db-name}}' \
        RedisPassword='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/redis-password}}' \
        QdrantApiKey='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/qdrant-api-key}}' \
        OpenAiApiKey='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/openai-api-key}}' \
        FindIpApiKey='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/findip-api-key}}' \
        JwtSecret='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/jwt-secret}}' \
        ProvidenceRootProject='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/root-project}}' \
        ProvidenceRootPassword='{{resolve:secretsmanager:/providence/'"${ENVIRONMENT}"'/root-password}}' &

# Capture the PID of the deployment process
DEPLOY_PID=$!

# Artifical pause to prevent initial error message while the stack is being created in AWS
sleep 15

# Start the monitoring loop
monitor_stack "providence-${ENVIRONMENT}"

# Wait for the deployment to finish and capture the exit status
wait "$DEPLOY_PID"
DEPLOY_STATUS=$?

if [ $DEPLOY_STATUS -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    
    # Display outputs
    aws cloudformation describe-stacks \
        --stack-name "providence-${ENVIRONMENT}" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
else
    echo ""
    echo "❌ Deployment failed"
    exit 1
fi