terraform {
  backend "s3" {
    bucket       = "aws-eks-terraform-platform-tfstate-794692802222"
    key          = "dev/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}