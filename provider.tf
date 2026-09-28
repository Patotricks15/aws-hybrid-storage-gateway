provider "aws" {
  region = var.aws_region

  # Temporary override to run this scaffold against the local Floci AWS emulator (http://localhost:4566).
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    efs            = "http://localhost:4566"
    storagegateway = "http://localhost:4566"
    backup         = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    sns            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}
