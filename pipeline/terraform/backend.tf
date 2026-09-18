# NovaPay Terraform Backend — S3 + DynamoDB for state locking
# State file must be encrypted and access-controlled for RBI compliance

terraform {
  backend "s3" {
    bucket         = "novapay-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "novapay-terraform-locks"
    kms_key_id     = "alias/novapay-terraform-state-key"
  }
}
