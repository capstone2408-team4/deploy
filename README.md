# Providence AWS Deployment

Deploy Providence to AWS in minutes using a single CloudFormation stack. This deployment creates a production-ready environment running on ECS Fargate with:

- Containerized services managed by ECS (Providence API, PostgreSQL, Redis, Qdrant)
- VPC networking with public/private subnets across multiple AZs
- Application Load Balancer for HTTPS termination and request distribution
- Persistent storage via EFS for data stores
- Service Discovery for internal container communication
- CloudWatch logging and monitoring integration

## Prerequisites

1. AWS Account and Permissions
   - New or existing [AWS account](https://aws.amazon.com/)
   - IAM user with appropriate permissions:
     - `AdministratorAccess` role (recommended for simplicity!)
     - Or custom IAM policy using our [permissions guide](docs/permissions.md)
   - [AWS CLI](https://aws.amazon.com/cli/) installed and configured

2. API Keys
   - [OpenAI API key](https://platform.openai.com/api-keys)
   - [FindIP](https://findip.net/) API key

3. Local Environment
   - Bash-compatible shell
   - [Git](https://git-scm.com/)

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/providence/deploy.git
   cd deploy
   ```

2. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   # Enter your AWS access key, secret key, and region
   ```

3. Create your environment file:
   ```bash
   cp .env.example .env
   # Edit .env and fill in all required values
   ```

   **Follow the .env.example as your guide. All listed variables are required. Remember to use strong passwords & secrets!**

4. Deploy:
   ```bash
   # First make the bash script executable:
   chmod +x deploy.sh  

   # Run the script
   ./deploy.sh
   ```

5. Access Providence:
   - Use the ALB URL from the deployment output to access the Providence dashboard

## Security Overview

The Providence AWS deployment implements several security best practices:

- All sensitive configuration values are stored encrypted in AWS Secrets Manager
- Services run in a private subnet with no direct public access
- Internal service communication is secured through AWS networking
- ECS services receive regular security patches through managed updates
- Infrastructure defined as code via CloudFormation for consistency and auditability

### SSL/TLS Configuration

By default, this deployment creates and uses a self-signed certificate for HTTPS:
- Enables encrypted communication immediately
- Browser security warnings will appear (expected with self-signed certs)
- Suitable for testing and evaluation

For prolonged production deployments, we recommend taking some additional steps:
1. Register a domain name for your Providence instance through AWS Route 53 or your preferred registrar.
2. Set up DNS management (either through your registrar or AWS Route 53).
3. Request a new certificate through AWS Certificate Manager (ACM) for your domain.
4. Complete domain validation (usually through DNS records).
5. Configure the ALB with this new certificate, replacing the self-signed certificate.
6. Point your domain to the ALB (typically through CNAME records).

Consult your domain registrar's documentation for detailed instructions on DNS management and domain configuration.

## Next Steps
- Visit the [Agent repository](https://github.com/providence-replay/agent) for instructions on instrumenting your application.
- Consider setting up additional monitoring and alerting through CloudWatch.
