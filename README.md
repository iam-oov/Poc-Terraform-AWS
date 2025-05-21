![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)
![Bash Script](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

Construido con ❤️ por [Valdo](https://github.com/iam-oov) usando Windsurf, Gemini y el conocimiento adquirido en el curso de Udemy "[Terraform, a popular infrastructure automation tool for DevOps. Terraform with AWS, Packer, Docker, ECS, EKS, Jenkins](https://www.udemy.com/course/learn-devops-infrastructure-automation-with-terraform/)".

## ToDo

- Agregar ECS a los archivos de terraform
- Separar los archivos tf usando modulos para ambientes STAGE y PROD
- Agregar un job para diferentes ramas STAGE y PROD
- Activar el job de PROD solo en PR de main

# POC: Node.js to AWS ECR with Terraform & GitHub Actions

This project serves as a Proof of Concept (PoC) demonstrating the deployment of a Node.js (Express) backend application, containerized with Docker, to Amazon Elastic Container Registry (ECR) using Terraform for infrastructure provisioning and GitHub Actions for CI/CD automation.

## Overview

The primary goal is to showcase an automated workflow where:

1.  Terraform defines and manages the AWS ECR repository and related resources.
2.  A local setup script (`setup_tf_backend.sh`) configures the Terraform backend using AWS S3 and DynamoDB.
3.  GitHub Actions, upon a push to the `main` branch, authenticates to AWS using an IAM Role (OIDC), builds the Docker image, and pushes it to the ECR repository provisioned by Terraform.

## Features

- Infrastructure as Code (IaC) using Terraform for AWS ECR.
- Automated CI/CD pipeline with GitHub Actions.
- Secure authentication to AWS from GitHub Actions using IAM Roles for Service Accounts (OIDC).
- Docker containerization of a Node.js Express application.
- Automated Terraform backend configuration (S3 bucket and DynamoDB table for state locking).

## Tech Stack

- **Cloud Provider:** AWS
  - ECR (Elastic Container Registry)
  - S3 (for Terraform backend state)
  - DynamoDB (for Terraform state locking)
  - IAM (Identity and Access Management - OIDC for GitHub Actions)
- **IaC:** Terraform
- **CI/CD:** GitHub Actions
- **Containerization:** Docker
- **Application:** Node.js (Express.js)

## Prerequisites

Before you begin, ensure you have the following installed and configured:

- [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [AWS CLI](https://aws.amazon.com/cli/)
- [Docker](https://docs.docker.com/get-docker/)
- An AWS Account.
- A GitHub Repository.

## Setup and Configuration

### 1. AWS IAM Role for GitHub Actions (OIDC)

Create an IAM Role in your AWS account that GitHub Actions can assume. This role needs permissions to manage ECR, S3 (for Terraform backend), and DynamoDB (for Terraform state lock table).

- Follow the AWS documentation for [Configuring OpenID Connect in Amazon Web Services](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html).
- The trust relationship for the IAM role should be configured for GitHub Actions. Example policy snippet:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringLike": {
            "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME:*"
          }
        }
      }
    ]
  }
  ```

- Attach necessary permission policies to this role (e.g., `AmazonEC2ContainerRegistryFullAccess`, plus custom policies for S3 backend bucket creation/access and DynamoDB table creation/access if the setup script handles this).

### 2. Configure GitHub Secrets

In your GitHub repository, navigate to `Settings > Secrets and variables > Actions` and add the following secrets:

- `AWS_REGION`: Your AWS region (e.g., `us-east-1`).
- `AWS_IAM_ROLE_ARN`: The ARN of the IAM role created in the previous step (e.g., `arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/YOUR_IAM_ROLE_NAME`).

### 3. Terraform Backend Setup Script

The `setup_tf_backend.sh` script automates the creation of the S3 bucket and DynamoDB table for the Terraform backend and generates the necessary Terraform configuration files.

- The script is expected to create:
  - `terraform/backend.tf`: Configures the S3 backend for Terraform state.
  - `terraform/variables.tf`: May define variables used by the backend setup or main configuration (e.g., `TF_STATE_KEY`, `TF_BACKEND_REGION` if these are dynamically set or user-provided).

**Note:** Ensure your Terraform configuration in the `terraform/` directory (especially `main.tf` or a dedicated backend setup file) defines the resources for the S3 bucket and DynamoDB table that the `setup_tf_backend.sh` script will use or create. The script utilizes outputs like `s3_backend_bucket_name` and `dynamodb_lock_table_name` from a preliminary Terraform apply for the backend resources.

## How to Run / Deployment Workflow

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME.git
    cd YOUR_REPOSITORY_NAME
    ```

2.  **Make the setup script executable:**

    ```bash
    chmod +x setup_tf_backend.sh
    ```

3.  **Run the setup script:**
    This script will typically run `terraform init` and `terraform apply` against a configuration designed to provision the S3 bucket and DynamoDB table for the state backend. It then uses the outputs to generate `terraform/auto_generated_backend.tf` (and potentially `terraform/auto_generated_variables.tf`).

    ```bash
    ./setup_tf_backend.sh
    ```

    Follow any prompts from the script.

4.  **Commit and Push Changes:**
    After the script successfully generates `terraform/auto_generated_backend.tf` and `terraform/auto_generated_variables.tf`, commit these files and any other changes to your repository:

    ```bash
    git add terraform/auto_generated_backend.tf terraform/auto_generated_variables.tf
    git commit -m "Configure Terraform backend"
    git push origin main
    ```

5.  **GitHub Actions Workflow:**
    Pushing to the `main` branch will trigger the GitHub Actions workflow defined in `.github/workflows/deploy-to-ecr.yml`. This workflow will:
    - Configure AWS credentials using the OIDC role.
    - Run `terraform init` and `terraform apply` to create/update the ECR repository defined in your main Terraform configuration (e.g., `terraform/main.tf`).
    - Build the Docker image using the `Dockerfile`.
    - Push the Docker image to the ECR repository.

## Project Structure

```
.
├── .github/workflows/       # GitHub Actions workflows
│   └── deploy-to-ecr.yml    # Workflow for ECR deployment
├── app/                     # Node.js application source code
│   ├── app.js               # Express application (e.g., Hello World on port 3011)
│   └── package.json         # Node.js dependencies
├── terraform/               # Terraform configuration files
│   ├── main.tf              # Main infrastructure (ECR repository, etc.)
│   ├── variables.tf         # Terraform input variables
│   ├── outputs.tf           # Terraform outputs (ECR URL, region)
│   └── backend.tf           # (Generated by setup_tf_backend.sh) Terraform backend config
├── Dockerfile               # Dockerfile to build the Node.js application image
├── setup_tf_backend.sh      # Script to setup Terraform backend and generate config
└── README.md                # This file
```
