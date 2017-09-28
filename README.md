terraform-ecs-bamboo
====================

## Objective
Deploy Atlassian Bamboo Server (standalone) to AWS EC2 Container Service and present License Setup via a IP-restricted Application Load Balancer.
Due to the licensing restrictions on this commercial product, some manual steps are currently needed.
However, once initial setup is complete and the Bamboo config and database is persisted, the service is self-healing after task/instance/AZ loss.

## Features
- Build a VPC over all AZs with public-facing subnets
- Create and deploy ECS instances across those subnets
- Create ECS service and connect EFS
- Deploy Docker image https://hub.docker.com/r/jimfdavies/bamboo-server-alpine/
- Create ALB and register ECS service to Target Group
- Deploy EFS filesystem and attach to all running instances

- TODO: Deploy empty PostgresDB instance on RDS
- TODO: Output service public IP and RDS endpoint
- TODO: Deploy automated backup service for config/data
- TODO: Deploy optional 'Bamboo restorer' service that re-hydrates config/data

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
