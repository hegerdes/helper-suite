terraform {
  required_version = ">=1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.23"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region  = "eu-central-1"
  profile = "aws-admin"
}

locals {
  src_path     = "${path.module}/python-src"
  project      = "hegerdes-aws-iam-web-id-test"
  binary_path  = abspath("${path.module}/builds/${local.project}")
  archive_path = "${local.binary_path}.zip"
  issuer       = "https://xxx.tokens.sts.global.api.aws"

  tags = {
    owner       = "Henrik Gerdes"
    cost-center = "default"
    project     = "hegerdes-aws-iam-web-id-test"
    status      = "active"
    managed-by  = "terraform"
    env         = "dev"
    repository  = "https://github.com/hegerdes/helper-suite"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~>8.1"

  function_name                     = local.project
  source_path                       = local.src_path
  handler                           = "main.handler"
  description                       = "Generate WebIdTokens with AWS STS"
  runtime                           = "python3.14"
  architectures                     = ["arm64"]
  authorization_type                = "NONE"
  role_name                         = "lambda-${local.project}"
  create_lambda_function_url        = true
  create_sam_metadata               = true
  cloudwatch_logs_retention_in_days = 7
  function_tags                     = local.tags
  cloudwatch_logs_tags              = local.tags
  local_existing_package            = "${path.module}/python-src/function.zip"
  environment_variables = {
    "AWS_ACCOUNT" : data.aws_caller_identity.current.account_id
    "AWS_ROLE_NAME" : module.lambda.lambda_role_name
    "OIDC_ISSUER" : local.issuer
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = module.lambda.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy_webid" {
  name   = "${local.project}-policy-webid"
  role   = module.lambda.lambda_role_name
  policy = data.aws_iam_policy_document.lambda_policy_webid.json
}

data "aws_iam_policy_document" "lambda_policy_webid" {
  statement {
    actions   = ["sts:GetWebIdentityToken", "sts:TagGetWebIdentityToken", "sts:SetContext"]
    effect    = "Allow"
    resources = ["*"]
    # condition {
    #   test     = "ForAnyValue:StringEquals"
    #   variable = "sts:IdentityTokenAudience"
    #   values   = ["https://api.hegerdes.com"]
    # }
    condition {
      test     = "StringEquals"
      variable = "sts:SigningAlgorithm"
      values   = ["ES384"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/account"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/issuer"
      values   = [local.issuer]
    }
    condition {
      test     = "NumericLessThanEquals"
      variable = "sts:DurationSeconds"
      values   = [300]
    }
  }
}



data "aws_caller_identity" "current" {}

output "lambda_url" {
  value = module.lambda.lambda_function_url
}
output "lambda_arn" {
  value = module.lambda.lambda_function_arn
}
output "lambda_role_arn" {
  value = module.lambda.lambda_role_arn
}

# data "aws_iam_policy_document" "github_actions" {
#   statement {
#     actions = [
#       "s3:PutObject",
#       "iam:ListRoles",
#       "lambda:UpdateFunctionCode",
#       "lambda:UpdateFunctionConfiguration",
#       "lambda:GetFunctionConfiguration",
#       "lambda:InvokeFunction",
#       "lambda:CreateFunction",
#       "lambda:GetFunction",
#     ]
#     resources = [module.lambda.lambda_function_arn]
#   }

#   statement {
#     actions = [
#       "ecr:GetAuthorizationToken",
#     ]
#     resources = ["*"]
#   }
# }
