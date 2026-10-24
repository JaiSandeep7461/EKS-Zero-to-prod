# Bootstrap must be applied first so this S3 bucket and lock table exist.
# Local operators set AWS_PROFILE=zero-to-prod; GitHub Actions uses OIDC
# credentials from the environment. Do not hardcode a profile in the backend.
terraform {
  backend "s3" {
    bucket         = "ztd-capstone-tfstate-921810470521"
    key            = "foundation/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ztd-capstone-tflock"
    encrypt        = true
  }
}
