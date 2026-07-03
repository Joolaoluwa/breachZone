terraform {
  backend "s3" {
    bucket         = "vaultcloud-tfstate"
    key            = "breach-zone/threat-detection/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vaultcloud-tf-locks"
    encrypt        = true
  }
}
