terraform-ecs-bamboo
====================

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

## Update
The VPC may not have finished by the time we refresh and populate data.aws_subnet_ids so you might get the following:
```
1 error(s) occurred:

* data.aws_subnet_ids.main: data.aws_subnet_ids.main: no matching subnet found for vpc with id vpc-xxxxxxxx
```
Just re-run the apply command until we improve the subnet collection
