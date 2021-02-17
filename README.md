# scalable-httpbin-aws-infra
A basic scalable AWS infra for [httpbin](https://github.com/postmanlabs/httpbin).

## Pre-requisites
To deploy this infra on AWS, you'll obviously need an AWS account.
This project has intentionally been created to be tested on AWS with a Free Tier account.
That's why some features have not been implemented, because they get out of the Free Tier policy (see the [Further improvements section](#further-improvements)).

You'll also need to have [terraform installed](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started), you can check that your terraform installation is correct by running this command in a shell:
```bash
$ terraform --version
Terraform v0.14.6
```

**Important note**: this recipe has been created with the v0.14.6 version of terraform, so be sure to use this specific version in case of syntax changes in the further versions.

In order for terraform to communicate with AWS, you'll need to properly setup your AWS credentials.
You can do so either by [using the aws-cli binary](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html), or simply by setting the needed environment variables:
```bash
$ export AWS_ACCESS_KEY_ID=<your AWS Access Key Id>
$ export AWS_SECRET_ACCESS_KEY=<your AWS Secret Access Key>
```

## How to use
With terraform and your AWS credentials correctly setup, you can now configure in which AWS region you want to create your infra in, by modifying the following configuration parameter in `variables.tf`:
```yaml
variable "aws-region" {
  description = "The AWS region to create the infrastructure in"
  default     = "eu-west-3"
}
```

You can also choose which CIDR block you want to assign to the created VPC:
```yaml
variable "vpc-cidr-block" {
  description = "The CIDR block for the VPC"
  default     = "172.32.0.0/16"
}
```

And finally, you can also choose the type of EC2 instance you want to use:
```yaml
variable "ec2-instance-type" {
  description = "The desired EC2 instance type"
  default     = "t2.micro"
}
```
Here `t2.micro` has been chosen as it's the only Free Tier instance type available.

You can then create the infrastructure with the following commands:
```bash
$ terraform init
$ terraform plan
$ terraform apply
```

After a few minutes, you will be given the URL of the newly created infrastructure:

```bash
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

alb-url = "Please connect to http://alb-XXXX.eu-west-3.elb.amazonaws.com/"
```

## Infrastructure overview
This recipe will deploy the following infrastructure:
- a VPC
- its associated subnets, 1 per available Availability Zone
- an Internet Gateway with its associated routing table
- an Application Load Balancer
- 2 Security Groups, describing the allowed in and out flows
- a Launch Template, describing the configuration of the EC2 instances
- an Auto Scaling Group with its associated Target Group, in charge of popping the EC2 instances based on the Launch Template
- and 2 Scaling Policies

Based on the Scaling Policies (more details in the [Scalability section](#scalability)), the ASG will automatically create the needed EC2 instances, and register them to the ALB Target Group.

## Security
To keep the infrastructure as much secure as possible, 2 Security Groups have been set:
- one to allow traffic from the Internet to the ALB, listening on port 80
- one to allow traffic from the ALB to the EC2 instances on port 8080

To be even more secure, the httpbin application has been setup to be run by the unprivileged user `httpbin-user`, so that in case of a privileges escalation vulnerability, the compromised user will be a simple user, and not `root`.

## Scalability
To keep the infrastructure robust in case of a traffic increase, a very simple scalability has been implemented:
- if the global ASG CPU Utilization goes over 80%, then add one EC2 instance to the ASG Target Group
- if the global ASG CPU Utilization goes below 20%, then remove one EC2 instance from the ASG Target Group

This is a very basic scalability implementation, and it can of course be tweaked in a more finely grained manner, for example to be based on other metrics (Memory usage, Network traffic...).

Also, by dynamically creating one subnet per AZ (see the [Implementation choices section](#implementation-choices)), we ensure that the EC2 instances will be evenly distributed across available AZs.

And because a minimum of 2 instances has been set in the ASG, we are resilient in case of one AZ outage.

## Implementation choices
The infrastructure has deliberately been designed to use public subnets, because using private networks would require the use of a NAT gateway.
But using such a gateway implies using an Elastic IP, which is unfortunately eligible (AFAIK) to a cost, and thus goes out of our 100% free approach.

**But** our EC2 instances are using a Security Group that, by default, only allows traffic coming from the Application Load Balancer, making them pretty secure.

The creation of the subnets has also been fully automated, so that independently of the chosen region, there will be 1 subnet per available Availability Zones.

So if you choose a region with, let's say, 2 AZs, there will be 2 subnets created.
In our case, eu-west-3, 3 subnets will be created, and the CIDR block they'll use will also be computed on the fly, based on the number of available AZs (see `vpc.tf`).

The source code of httpbin has also been modified to display the hostname of the EC2 instance it's running on, to clearly demonstrate the load balancing in action.

There is also a simple CI, using GitHub actions, that checks the syntax of the terraform files, with `tflint`, `terraform fmt` and `terraform plan`.

## Further improvements
- add HTTPS support

As for the NAT Gateway, using HTTPS requires the use of the Amazon Certificate Manager and an associated domain name, which also goes out of our 100% free approach.

- create a custom AMI, with httpbin and its dependencies already installed, to reduce the launch time of the EC2 instances

This creation requires a lot of temporary work to be fully automated: creation of a temporary EC2 instance, then a snapshot of its root storage, and finally a custom AMI from this snapshot.
So it is questionable to automate this task, regarding the little time gained on EC2 instances creation.

- Continuous Delivery

You can even go further, and automatically apply the changes to your infra on a push event to the main branch (for example after a merge of a GitHub PR).
For this, you will need:
  - to un-comment the related commands in `.github/workflows/terraform.yml`.
  - to store the file containing the current state of the infra seen by terraform `terraform.tfstate` on a shared storage, for example on AWS S3, for it to be persistent across CD runs. For this, create a `backend.tf` file in the root directory of this repository, and add the following configuration:
```yaml
terraform {
  backend "s3" {
    bucket = "mybucket"
    key    = "path/to/my/key"
    region = var.aws-region
  }
}
```
