terraform {
  backend "s3" {
    bucket  = "hegerdes-default"
    key     = "hegerdes/tf/aws-iam-web-id-test.tfstate"
    region  = "eu-central-1"
    profile = "aws-admin"
  }
}
