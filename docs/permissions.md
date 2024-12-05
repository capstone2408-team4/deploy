# Providence AWS Permissions Guide

For users who need more restrictive permissions than `AdministratorAccess`.

## Workflow Overview

1. Administrator creates custom IAM policy with Providence deployment permissions
2. Administrator attaches policy to less privileged IAM user
3. Less privileged IAM user can then run Providence deployments

## Setup Instructions

1. Save the policy document:
   - Create a new file named `providence-policy.json`
   - Copy the policy JSON from the section below into this file
   - Save the file locally

2. Create the IAM policy:
   ```bash
   # Create the policy
   aws iam create-policy \
     --policy-name providence-deploy \
     --policy-document file://providence-policy.json
   ```

3. Attach the policy to the target IAM user:
   ```bash
   # List IAM users to find the target username
   aws iam list-users

   # Attach the policy (replace the placeholder values)
   aws iam attach-user-policy \
     --user-name TARGET_USERNAME \
     --policy-arn arn:aws:iam::TARGET_ACCOUNT_ID:policy/providence-deploy
   ```

4. Verify the policy attachment:
   ```bash
   aws iam list-attached-user-policies --user-name TARGET_USERNAME
   ```

The target IAM user can now proceed with the Providence deployment using these restricted permissions instead of requiring full administrative access.

## Required Resources Access

The provided policy allows management of:
- CloudFormation stacks prefixed with 'providence-'
- IAM roles, policies, and service-linked roles
- VPC and networking resources (including VPC endpoints)
- ECS clusters, services, and tasks
- Load balancers and target groups
- Secrets Manager secrets under /providence/*
- CloudWatch logs under /providence* prefix
- S3 buckets prefixed with 'providence-'
- EFS file systems and access points
- Service Discovery (AWS Cloud Map) resources
- ACM certificates and SSM parameters

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
              "cloudformation:*ChangeSet*",
              "cloudformation:ListExports",
              "cloudformation:ListImports"
          ],
          "Resource": "arn:aws:cloudformation:*:*:stack/providence-*/*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "cloudformation:ValidateTemplate",
              "cloudformation:ListStacks",
              "cloudformation:CreateUploadBucket"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "iam:CreateRole",
              "iam:DeleteRole",
              "iam:GetRole",
              "iam:PutRolePolicy",
              "iam:DeleteRolePolicy",
              "iam:AttachRolePolicy",
              "iam:DetachRolePolicy",
              "iam:TagRole",
              "iam:UntagRole",
              "iam:PassRole",
              "iam:CreateServiceLinkedRole",
              "iam:DeleteServiceLinkedRole",
              "iam:GetServiceLinkedRoleDeletionStatus"
          ],
          "Resource": [
              "arn:aws:iam::*:role/providence-*",
              "arn:aws:iam::*:role/aws-service-role/ecs.amazonaws.com/*",
              "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/*"
          ]
      },
      {
          "Effect": "Allow",
          "Action": [
              "ec2:*Vpc*", 
              "ec2:*Subnet*",
              "ec2:*SecurityGroup*", 
              "ec2:*Route*",
              "ec2:*Gateway*", 
              "ec2:*Address*",
              "ec2:*Endpoint*",
              "ec2:*NetworkInterface*",
              "ec2:CreateTags",
              "ec2:DeleteTags",
              "ec2:Describe*"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ecs:*Cluster*", 
              "ecs:*Service*",
              "ecs:*Task*", 
              "ecs:*Container*",
              "ecs:*ExecuteCommand*",
              "ecs:*Capacity*",
              "ecs:PutAccountSetting*",
              "ecs:List*", 
              "ecs:Describe*",
              "ecs:Poll",
              "ecs:StartTelemetrySession"
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
              "secretsmanager:CreateSecret",
              "secretsmanager:DeleteSecret",
              "secretsmanager:GetSecretValue",
              "secretsmanager:PutSecretValue",
              "secretsmanager:UpdateSecret",
              "secretsmanager:DescribeSecret",
              "secretsmanager:ListSecrets",
              "secretsmanager:TagResource"
          ],
          "Resource": "arn:aws:secretsmanager:*:*:secret:/providence/*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "logs:CreateLogGroup",
              "logs:DeleteLogGroup",
              "logs:PutRetentionPolicy",
              "logs:CreateLogStream",
              "logs:DeleteLogStream",
              "logs:PutLogEvents",
              "logs:GetLogEvents",
              "logs:FilterLogEvents",
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams"
          ],
          "Resource": [
              "arn:aws:logs:*:*:log-group:/providence*",
              "arn:aws:logs:*:*:log-group:providence-*"
          ]
      },
      {
          "Effect": "Allow",
          "Action": [
              "s3:*"
          ],
          "Resource": [
              "arn:aws:s3:::providence-*"
          ]
      },
      {
          "Effect": "Allow",
          "Action": [
              "servicediscovery:CreatePrivateDnsNamespace",
              "servicediscovery:DeleteNamespace",
              "servicediscovery:GetNamespace",
              "servicediscovery:GetOperation",
              "servicediscovery:ListOperations",
              "servicediscovery:CreateService",
              "servicediscovery:DeleteService",
              "servicediscovery:GetService",
              "servicediscovery:ListServices",
              "servicediscovery:TagResource",
              "servicediscovery:RegisterInstance",
              "servicediscovery:DeregisterInstance",
              "servicediscovery:GetInstance",
              "servicediscovery:ListInstances"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "elasticfilesystem:CreateFileSystem",
              "elasticfilesystem:DeleteFileSystem",
              "elasticfilesystem:CreateMountTarget",
              "elasticfilesystem:DeleteMountTarget",
              "elasticfilesystem:CreateAccessPoint",
              "elasticfilesystem:DeleteAccessPoint",
              "elasticfilesystem:DescribeFileSystems",
              "elasticfilesystem:DescribeMountTargets",
              "elasticfilesystem:DescribeAccessPoints",
              "elasticfilesystem:UpdateFileSystem",
              "elasticfilesystem:TagResource",
              "elasticfilesystem:UntagResource"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "acm:RequestCertificate",
              "acm:ImportCertificate",
              "acm:DeleteCertificate",
              "acm:DescribeCertificate",
              "acm:ListCertificates",
              "acm:AddTagsToCertificate",
              "acm:RemoveTagsFromCertificate",
              "acm:UpdateCertificateOptions"
          ],
          "Resource": "arn:aws:acm:*:*:certificate/*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "route53:CreateHostedZone",
              "route53:DeleteHostedZone",
              "route53:GetHostedZone",
              "route53:ListHostedZones",
              "route53:GetChange",
              "route53:ChangeResourceRecordSets",
              "route53:ListResourceRecordSets"
          ],
          "Resource": "*"
      }
  ]
}
```

## Notes

- Policy uses resource-level restrictions where supported
- Some services require "*" resource due to AWS limitations
- All created resources use 'providence-' prefix
- Policy allows full lifecycle management (create/update/delete)
- ECS ExecuteCommand features and SSM session management included
- Service-linked role creation is needed for ECS and ELB included
