provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      project    = var.project
      managed-by = "terraform"
      layer      = "foundation"
    }
  }
}
