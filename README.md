terraform-ecs-bamboo
====================

## Objective
Deploy Atlassian Bamboo Server (standalone) to AWS EC2 Container Service and present License Setup via a IP-restricted Application Load Balancer.
Due to the licensing restrictions on this commercial product, some manual steps are currently needed. Once initial setup is complete however, the objective is to be self-healing after host instance/AZ loss.

## Features
- Build a VPC over all AZs with public-facing subnets
- Create and deploy ECS instances across those subnets
- Create ECS service and connect EFS
- Deploy Docker image https://hub.docker.com/r/jimfdavies/bamboo-server-alpine/
- Create ALB and register ECS service to Target Group

TODO:
- Deploy EFS filesystem and attach to all running instances
- Deploy empty PostGresDB instance on RDS
- Output service public IP and RDS endpoint

Takes you as far as the license page when you connect. You will need to add your own license and run the Custom Installation connecting to the RDS instance.
this config will be stored on the EFS volume at /home/bamboo.

## Usage

Plan
```
terraform plan \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32'
```
Apply
```
terraform apply \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32'
```
Destroy
```
terraform destroy \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32'
```
