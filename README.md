terraform-ecs-bamboo
====================

## Overview
- Build a VPC over all AZs with public-facing subnets
- Create and deploy ECS instances across those subnets

TODO:
- Deploy EFS filesystem and attach to all running instances
- Deploy empty PostGresDB instance on RDS
- Create ECS service and connect EFS
- Deploy Docker image https://hub.docker.com/r/jimfdavies/bamboo-server-alpine/
- Output service public IP and RDS endpoint
- (Future: Add ALB and service auto-enrollment)

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

### Update
The VPC may not have finished by the time we refresh and populate data.aws_subnet_ids so you might get the following:
```
1 error(s) occurred:

* data.aws_subnet_ids.main: data.aws_subnet_ids.main: no matching subnet found for vpc with id vpc-xxxxxxxx
```
Just re-run the apply command until we improve the subnet collection
