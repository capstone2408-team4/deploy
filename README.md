# Providence Deployment

Deploy Providence to AWS in minutes.

## Prerequisites

1. AWS Account
   - New or existing AWS account
   - IAM user with necessary permissions (`AdminAccess` recommended!!)
   - AWS CLI installed and configured

2. API Keys
   - OpenAI API key
   - FindIP API key

3. Local Environment
   - Bash-compatible shell
   - Git

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/providence/deploy.git
   cd deploy
   ```

2. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   # Enter your AWS access key, secret key, and region (us-east-1)
   ```

3. Create your environment file:
   ```bash
   cp .env.example .env
   # Edit .env and fill in all required values
   ```

4. Deploy:
   ```bash
   ./deploy.sh
   ```

5. Access Providence:
   - Use the URL from deployment outputs
   - Login with PROVIDENCE_ROOT_PROJECT/PASSWORD from .env

## Common Issues

1. "AWS CLI not authenticated"
   - Run `aws configure` with valid credentials

2. "Missing required variables"
   - Ensure all values in .env are filled

3. "Deployment failed"
   - Check CloudFormation console for error details
   - Ensure account has no service limits blocking deployment

## Security Notes

- All sensitive values are stored encrypted in AWS Parameter Store
- Services run in private subnets with no public access
- Communication secured through internal AWS networking
- Regular security patches via managed ECS services

### SSL Certificate
This deployment uses a self-signed certificate for HTTPS. This means:
- Your browser will show a security warning
- You'll need to click through the warning to access the application
- This is appropriate for testing but NOT for production use

For production deployments, you should:
- Use a proper domain name
- Switch to AWS Certificate Manager (ACM)
- Remove the self-signed certificate configuration