terraform {
  backend "s3" {
    bucket       = "ztd-capstone-tfstate-921810470521"
    key          = "stack/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
