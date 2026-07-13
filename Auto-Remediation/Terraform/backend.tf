## terraform {
## backend "s3" {
## bucket         = "bucket-name1.0"
## key            = "d5/terraform.tfstate"
## region         = "us-east-1"
## dynamodb_table = "vaultcloud-tf-locks"
## encrypt        = true
## }
## }