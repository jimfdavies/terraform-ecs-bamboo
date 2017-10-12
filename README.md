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
- Deploy empty PostgresDB instance on RDS
- Output service public IP and RDS endpoint

- TODO: Deploy an ECS Service of Bamboo Agents (registering would be manual post-setup)
- TODO: Deploy automated backup service for config/data
- TODO: Deploy optional 'Bamboo restorer' service that re-hydrates config/data
- TODO: Optionally, use Terraform File provisioner to populate initial config

Takes you as far as the license page when you connect. You will need to add your own license and run the Custom Installation connecting to the RDS instance.
this config will be stored on the EFS volume at /home/bamboo.

## Usage

Plan
```
terraform plan \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32' \
  -var 'key_name=bamboo-ecs' \
  -var 'db_username=master' \
  -var 'db_password=changemerightmeow'
```
Apply
```
terraform apply \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32' \
  -var 'key_name=bamboo-ecs' \
  -var 'db_username=master' \
  -var 'db_password=changemerightmeow'
```
Destroy
```
terraform destroy \
  -var 'shared_credentials_file=~/.aws/credentials.personal' \
  -var 'admin_cidr_ingress=1.2.3.4/32' \
  -var 'key_name=bamboo-ecs' \
  -var 'db_username=master' \
  -var 'db_password=changemerightmeow'
```

## Bamboo setup

Note: The Server service can take up to three minutes to start up and register with the ALB.

When Apply has finished, follow official [Bamboo Setup Wizard](https://confluence.atlassian.com/bamboo/running-the-setup-wizard-289276851.html) using the Outputs from the Terraform run.

## Security notes

If you are concerned with security, you may want to consider extending this configuration with these recommendations.

- Add HTTPS (with a genuine DNS domain) to the ALB (use Route 53)
- Add SSL to the Agent communications
- Create a new ECS cluster for the Agents so the instance hosts don't have the EFS share mounted
- Create 'private' subnets and deploy ECS instances to that
