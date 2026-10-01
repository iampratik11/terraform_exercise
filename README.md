# Terraform Exercise: Provisioning AWS EC2 with Infrastructure as Code

[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.2-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![AWS Provider](https://img.shields.io/badge/AWS%20Provider-~%3E%205.92-FF9900?logo=amazonaws&logoColor=white)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Backend](https://img.shields.io/badge/Remote%20State-S3-569A31?logo=amazons3&logoColor=white)](https://developer.hashicorp.com/terraform/language/backend/s3)

A hands-on walkthrough based on the [HashiCorp Terraform tutorials](https://developer.hashicorp.com/terraform/tutorials/aws-get-started). It covers installing Terraform, provisioning an AWS EC2 instance, managing it with variables and outputs, destroying it, and storing state remotely in an S3 backend.

**Author:** Pratik Wagh
**Repository:** [github.com/iampratik11/terraform_exercise](https://github.com/iampratik11/terraform_exercise)

---

## Table of Contents

1. [About Infrastructure as Code](#about-infrastructure-as-code)
2. [What This Project Does](#what-this-project-does)
3. [Prerequisites](#prerequisites)
4. [Project Structure](#project-structure)
5. [Installing Terraform](#installing-terraform)
6. [Configuration Overview](#configuration-overview)
7. [Usage](#usage)
   - [Create Infrastructure](#1-create-infrastructure)
   - [Manage Infrastructure](#2-manage-infrastructure)
   - [Destroy Infrastructure](#3-destroy-infrastructure)
   - [Store Remote State in S3](#4-store-remote-state-in-s3)
8. [Command Reference](#command-reference)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [References](#references)

---

## About Infrastructure as Code

**Infrastructure as Code (IaC)** is the practice of creating, configuring, and managing infrastructure using machine-readable configuration files, rather than manually configuring resources through a web console.

Instead of clicking through the console to create servers, networks, and databases, you write code that describes the infrastructure you want, and a tool such as Terraform creates it for you. This makes infrastructure repeatable, version-controlled, and reviewable.

## What This Project Does

| Stage | Description |
|-------|-------------|
| **Install** | Set up Terraform on Ubuntu/Debian using the official HashiCorp APT repository |
| **Create** | Provision an EC2 instance running Ubuntu 24.04 (Noble), with the AMI discovered through a data source |
| **Manage** | Refactor hard-coded values into input variables, add outputs, and change the instance type in place |
| **Destroy** | Tear down all managed resources cleanly |
| **Remote state** | Move Terraform state to an S3 backend for durability and collaboration |

## Prerequisites

- An **AWS account** with permissions to create EC2 instances and read/write S3 objects
- **AWS credentials** configured locally (for example with `aws configure`, or the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment variables)
- **Terraform** `>= 1.2` (tested with `v1.16.3` on `linux_amd64`)
- A Linux shell. The install steps below target **Ubuntu/Debian**
- For the remote-state section: an existing **S3 bucket** with a globally unique name

> **Cost notice:** The resources in this exercise can incur AWS charges. Run `terraform destroy` when you finish.

## Project Structure

```text
learn-terraform-get-started-aws/
├── terraform.tf      # Terraform settings, required providers, and backend
├── main.tf           # Provider, AMI data source, and EC2 resource
├── variables.tf      # Input variables
├── outputs.tf        # Output values
└── .terraform.lock.hcl   # Provider version lock file (commit this)
```

## Installing Terraform

These steps follow HashiCorp's official instructions for Ubuntu/Debian.

**1. Install prerequisites**

```bash
sudo apt-get install -y gnupg software-properties-common
```

**2. Add HashiCorp's GPG key**

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

**3. Add the HashiCorp repository**

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
```

**4. Update APT and install Terraform**

```bash
sudo apt update
sudo apt-get install terraform
```

**5. Verify the installation**

```bash
terraform version
```

> For other operating systems, see the [official install guide](https://developer.hashicorp.com/terraform/install).

## Configuration Overview

### `terraform.tf`: settings and providers

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}
```

### `main.tf`: provider, data source, and resource

```hcl
provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}
```

The `aws_ami` data source always resolves the latest Canonical Ubuntu 24.04 image, so no AMI ID is hard-coded.

### `variables.tf`: input variables

```hcl
variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "learn-terraform"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t3.micro"
}
```

### `outputs.tf`: output values

```hcl
output "instance_hostname" {
  description = "Private DNS name of the EC2 instance."
  value       = aws_instance.app_server.private_dns
}
```

## Usage

### 1. Create infrastructure

```bash
git clone https://github.com/iampratik11/terraform_exercise.git
cd terraform_exercise/learn-terraform-get-started-aws
```

Run the standard Terraform workflow:

```bash
terraform fmt        # Format configuration files
terraform init       # Download providers and initialize the working directory
terraform validate   # Check the configuration is valid
terraform plan       # Preview the changes
terraform apply      # Create the infrastructure (type "yes" to confirm)
```

A successful apply ends with:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Confirm the instance in the AWS Console under **EC2 → Instances**, where it appears as `learn-terraform` in the **Running** state.

`terraform init` also creates `.terraform.lock.hcl`, which records the exact provider versions selected (here `hashicorp/aws v5.100.0`). Commit this file to version control so future runs use the same versions.

### 2. Manage infrastructure

**Use variables.** Hard-coded values in `main.tf` are replaced with `var.instance_type` and `var.instance_name`, defined in `variables.tf`. Apply again to confirm the plan is unchanged.

**Add outputs.** After adding `outputs.tf`, run `terraform apply`. Terraform prints the instance's private DNS name.

**Change the instance type.** Override a variable from the command line, with no file edits:

```bash
terraform apply -var="instance_type=t3.small"
```

```text
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

Outputs:

instance_hostname = "ip-172-31-13-209.us-east-2.compute.internal"
```

The instance is modified to `t3.small` and passes its 3/3 status checks. To make the change permanent, update the `default` in `variables.tf`.

### 3. Destroy infrastructure

```bash
terraform destroy
```

Terraform shows what will be removed (`Plan: 0 to add, 0 to change, 1 to destroy.`) and asks for confirmation. Type `yes` to proceed:

```text
Destroy complete! Resources: 1 destroyed.
```

### 4. Store remote state in S3

By default, Terraform stores state locally in `terraform.tfstate`. A remote backend keeps state durable, shareable, and out of your working directory.

Add a `backend` block to `terraform.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

  backend "s3" {
    bucket = "<your-unique-bucket-name>"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}
```

> Replace `<your-unique-bucket-name>` with your own S3 bucket, and set `region` to the region where that bucket lives. The bucket must exist before you run `terraform init`.

Re-initialize so Terraform configures the backend:

```bash
terraform init
```

```text
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

After the next `terraform apply`, the `terraform.tfstate` object appears in your S3 bucket.

## Command Reference

| Command | Purpose |
|---------|---------|
| `terraform fmt` | Rewrite configuration files to the canonical format |
| `terraform init` | Initialize the directory, install providers, configure the backend |
| `terraform validate` | Check that the configuration is syntactically valid |
| `terraform plan` | Show the execution plan without making changes |
| `terraform apply` | Create or update infrastructure |
| `terraform apply -var="name=value"` | Apply with a variable override |
| `terraform output` | Display output values |
| `terraform destroy` | Destroy all managed infrastructure |
| `terraform version` | Show the installed Terraform and provider versions |

## Best Practices

- **Commit `.terraform.lock.hcl`** to keep provider versions consistent across machines.
- **Never commit state files** (`*.tfstate`, `*.tfstate.backup`) or the `.terraform/` directory. Add them to `.gitignore`.
- **Never hard-code credentials.** Use environment variables, shared credential files, or IAM roles.
- **Run `plan` before `apply`** and review the diff.
- **Enable versioning and encryption** on the S3 bucket that holds your state. For team use, add state locking (for example with DynamoDB or S3 native locking).
- **Always destroy** practice resources when you finish to avoid unexpected charges.

Suggested `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
*.tfvars
```

## Troubleshooting

| Problem | Likely cause and fix |
|---------|----------------------|
| `terraform: command not found` | Terraform is not installed or not on your `PATH`. Re-run the install steps and check with `terraform version`. |
| `No valid credential sources found` | AWS credentials are not configured. Run `aws configure` or export the AWS environment variables. |
| `terraform init` fails on the S3 backend | The bucket does not exist, the name or region is wrong, or your credentials lack S3 permissions. |
| Instance appears in an unexpected region | The `region` in the `provider "aws"` block controls where resources are created. Check it against the region selected in the AWS Console. |
| "Your version of Terraform is out of date" | This is an informational notice. Upgrade through your package manager when convenient. |

## References

- [HashiCorp Terraform: AWS Get Started tutorials](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)
- [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [Terraform AWS Provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Source repository](https://github.com/iampratik11/terraform_exercise)

---

*Created by Pratik Wagh as part of a DevOps assignment.*
