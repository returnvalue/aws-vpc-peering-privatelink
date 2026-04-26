# AWS Secure Internal Networking Lab (VPC Peering & PrivateLink)

This lab demonstrates advanced networking and security patterns for the **AWS SysOps Administrator Associate**: connecting isolated networks and accessing services privately.

## Architecture Overview

The system implements a multi-VPC secure connectivity model:

1.  **VPC Peering:** A direct network connection between two VPCs (\`requester-vpc\` and \`accepter-vpc\`) that allows routing traffic between them using private IP addresses.
2.  **Cross-VPC Routing:** Route tables in both VPCs are updated to recognize the peering connection as the target for the other VPC's CIDR range.
3.  **VPC Endpoint (PrivateLink):** An Interface Endpoint is established in the requester VPC, allowing instances to communicate with the AWS Secrets Manager service over the AWS internal network, bypassing the public internet.
4.  **Internal Security:** A Security Group restricts traffic to only allow communication from the peered network CIDR.

## Key Components

-   **VPC Peering Connection:** The secure, non-transitive tunnel between network boundaries.
-   **Static Routing:** Orchestrated route updates for seamless inter-VPC communication.
-   **Interface VPC Endpoints:** Powered by PrivateLink for high-security service access.
-   **Multi-VPC Architecture:** Demonstrates isolation and controlled connectivity.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To test the internal connectivity:

1.  **Verify Peering Status:**
    ```bash
    awslocal ec2 describe-vpc-peering-connections
    aws ec2 describe-vpc-peering-connections
    ```
    Confirm the \`Status\` is \`active\`.

2.  **Check Routing Tables:**
    Verify that the route to \`10.2.0.0/16\` points to the peering connection:
    ```bash
    awslocal ec2 describe-route-tables --filters "Name=vpc-id,Values=<REQUESTER_VPC_ID>"
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<REQUESTER_VPC_ID>"
    ```

3.  **Inspect VPC Endpoint:**
    ```bash
    awslocal ec2 describe-vpc-endpoints
    aws ec2 describe-vpc-endpoints
    ```
    Confirm the Secrets Manager endpoint is \`Available\`.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
