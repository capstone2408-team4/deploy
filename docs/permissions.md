# Providence AWS Permissions Guide

For users who need more restrictive permissions than AdminAccess.

## Quick Setup

1. Create policy:
   ```bash
   aws iam create-policy \
     --policy-name providence-deploy \
     --policy-document file://providence-policy.json
   ```

2. Attach to user:
   ```bash
   aws iam attach-user-policy \
     --user-name YOUR_USERNAME \
     --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/providence-deploy
   ```

## Required Resources Access

The provided policy allows management of:
- CloudFormation stacks prefixed with 'providence-'
- IAM roles prefixed with 'providence-'
- VPC and networking resources
- ECS clusters and services
- Load balancers and target groups
- Parameter Store under /providence/*
- CloudWatch logs under /aws/providence*
- S3 buckets prefixed with 'providence-'
- EFS file systems for persistence
- Service Discovery resources
- ACM certificates for HTTPS load balancer

## Policy File
Save as `providence-policy.json`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*Stack*",
                "cloudformation:*Template*",
                "cloudformation:*ChangeSet*"
            ],
            "Resource": "arn:aws:cloudformation:*:*:stack/providence-*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:*Role*",
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::*:role/providence-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*Vpc*", "ec2:*Subnet*",
                "ec2:*SecurityGroup*", "ec2:*Route*",
                "ec2:*Gateway*", "ec2:*Address*",
                "ec2:CreateTags", "ec2:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:*Cluster*", "ecs:*Service*",
                "ecs:*Task*", "ecs:*Container*",
                "ecs:List*", "ecs:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:*Parameter*"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/providence/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:*Log*"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:/aws/providence*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::providence-*",
                "arn:aws:s3:::providence-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicediscovery:*",
                "elasticfilesystem:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "acm:ImportCertificate",
                "acm:DeleteCertificate",
                "acm:DescribeCertificate",
                "acm:ListCertificates"
            ],
            "Resource": "arn:aws:acm:*:*:certificate/*"
        }
    ]
}
```

## Notes

- Policy uses resource-level restrictions where supported
- Some services require "*" resource due to AWS limitations
- All created resources use 'providence-' prefix
- Policy allows full lifecycle management (create/update/delete)