terraform {
  backend "s3" {
    bucket         = "hotel-terraform-state"
    key            = "envs/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-terraform-locks"
    encrypt        = true
  }
}
