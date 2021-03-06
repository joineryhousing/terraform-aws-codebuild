data "aws_caller_identity" "default" {}

data "aws_region" "default" {}

# Define composite variables for resources
module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.0"
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  attributes = "${var.attributes}"
  tags       = "${var.tags}"
}

#TODO: selectively disable if cache is s3
# resource "aws_s3_bucket" "cache_bucket" {
#   count         = "${var.enabled == "true" && var.cache_enabled == "true" ? 1 : 0}"
#   bucket        = "${local.cache_bucket_name_normalised}"
#   acl           = "private"
#   force_destroy = true
#   tags          = "${module.label.tags}"

#   lifecycle_rule {
#     id      = "codebuildcache"
#     enabled = true

#     prefix = "/"
#     tags   = "${module.label.tags}"

#     expiration {
#       days = "${var.cache_expiration_days}"
#     }
#   }
# }

#TODO: selectively disable if cache is s3
# resource "random_string" "bucket_prefix" {
#   length  = 12
#   number  = false
#   upper   = false
#   special = false
#   lower   = true
# }

##TODO: selectively disable if cache is s3
# locals {
#   cache_bucket_name = "${module.label.id}${var.cache_bucket_suffix_enabled == "true" ? "-${random_string.bucket_prefix.result}" : "" }"

#   ## Clean up the bucket name to use only hyphens, and trim its length to 63 characters.
#   ## As per https://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html
#   cache_bucket_name_normalised = "${substr(join("-", split("_", lower(local.cache_bucket_name))), 0, min(length(local.cache_bucket_name),63))}"

#   ## This is the magic where a map of a list of maps is generated
#   ## and used to conditionally add the cache bucket option to the
#   ## aws_codebuild_project
#   cache_def = {
#     "true" = [{
#       type     = "S3"
#       location = "${var.enabled == "true" && var.cache_enabled == "true" ? join("", aws_s3_bucket.cache_bucket.*.bucket) : "none" }"
#     }]

#     "false" = []
#   }

#   # Final Map Selected from above
#   cache = "${local.cache_def[var.cache_enabled]}"
# }

resource "aws_iam_role" "default" {
  count              = "${var.enabled == "true" ? 1 : 0}"
  name               = "${module.label.id}"
  assume_role_policy = "${data.aws_iam_policy_document.role.json}"
}

data "aws_iam_policy_document" "role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_policy" "default" {
  count  = "${var.enabled == "true" ? 1 : 0}"
  name   = "${module.label.id}"
  path   = "/service-role/"
  policy = "${data.aws_iam_policy_document.permissions.json}"
}

# #TODO: selectively disable if cache is s3
# resource "aws_iam_policy" "default_cache_bucket" {
#   count  = "${var.enabled == "true" && var.cache_enabled == "true" ? 1 : 0}"
#   name   = "${module.label.id}-cache-bucket"
#   path   = "/service-role/"
#   policy = "${data.aws_iam_policy_document.permissions_cache_bucket.json}"
# }

#TODO: add permissions as a parameter so that certain build stages don't need the same permissions
data "aws_iam_policy_document" "permissions" {
  statement {
    sid = ""

    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Head*",
      "ec2:Describe*",
      "ec2:Get*",
      "ecr:BatchCheck*",
      "ecr:BatchGet*",
      "ecr:Describe*",
      "ecr:Get*",
      "ecr:List*",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:RunTask",
      "route53:Get*",
      "route53:List*",
      "iam:PassRole",
      "iam:Get*",
      "events:DescribeRule",
      "events:List*",
      "events:PutTargets",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:ListTagsLogGroup",
      "ssm:GetParameters",
      "elasticloadbalancing:Describe*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "dynamodb:Get*",
      "dynamodb:List*",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "logs:Describe*",
      "logs:Get*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy"
    ]

    effect = "Allow"

    resources = [
      "*",
    ]
  }
}

#TODO: selectively disable if cache is s3
# data "aws_iam_policy_document" "permissions_cache_bucket" {
#   count = "${var.enabled == "true" ? 1 : 0}"

#   statement {
#     sid = ""

#     actions = [
#       "s3:*",
#     ]

#     effect = "Allow"

#     resources = [
#       "${aws_s3_bucket.cache_bucket.arn}",
#       "${aws_s3_bucket.cache_bucket.arn}/*",
#     ]
#   }
# }

resource "aws_iam_policy" "default_s3_bucket" {
  count  = "${var.enabled == "true" && var.s3_bucket_name != "" ? 1 : 0}"
  name   = "${module.label.id}-s3-bucket"
  path   = "/service-role/"
  policy = "${data.aws_iam_policy_document.default_s3_bucket.json}"
}

data "aws_iam_policy_document" "default_s3_bucket" {
  count = "${var.enabled == "true" && var.s3_bucket_name != "" ? 1 : 0}"

  statement {
    sid = ""

    actions = [
      "s3:*",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "default_s3_bucket" {
  count = "${var.enabled == "true" && var.s3_bucket_name != "" ? 1 : 0}"
  policy_arn = "${element(aws_iam_policy.default_s3_bucket.*.arn, count.index)}"
  role       = "${aws_iam_role.default.id}"
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = "${var.enabled == "true" ? 1 : 0}"
  policy_arn = "${aws_iam_policy.default.arn}"
  role       = "${aws_iam_role.default.id}"
}

##TODO: selectively disable if cache is s3
# resource "aws_iam_role_policy_attachment" "default_cache_bucket" {
#   count      = "${var.enabled == "true" && var.cache_enabled == "true" ? 1 : 0}"
#   policy_arn = "${element(aws_iam_policy.default_cache_bucket.*.arn, count.index)}"
#   role       = "${aws_iam_role.default.id}"
# }

resource "aws_codebuild_project" "default" {
  count         = "${var.enabled == "true" ? 1 : 0}"
  name          = "${module.label.id}"
  service_role  = "${aws_iam_role.default.arn}"
  badge_enabled = "${var.badge_enabled}"
  build_timeout = "${var.build_timeout}"

  artifacts {
    type = "${var.artifact_type}"
  }

  lifecycle {
    ignore_changes = ["cache"]
  }

  # TODO: https://github.com/terraform-providers/terraform-provider-aws/issues/7643
  # cache = {
  #   type = "LOCAL",
  #   mode = "LOCAL_DOCKER_LAYER_CACHE"
  # }

  environment {
    compute_type    = "${var.build_compute_type}"
    image           = "${var.build_image}"
    type            = "LINUX_CONTAINER"
    privileged_mode = "${var.privileged_mode}"

    environment_variable = [{
      "name"  = "AWS_REGION"
      "value" = "${signum(length(var.aws_region)) == 1 ? var.aws_region : data.aws_region.default.name}"
      },
      {
        "name"  = "AWS_ACCOUNT_ID"
        "value" = "${signum(length(var.aws_account_id)) == 1 ? var.aws_account_id : data.aws_caller_identity.default.account_id}"
      },
      {
        "name"  = "IMAGE_REPO_NAME"
        "value" = "${signum(length(var.image_repo_name)) == 1 ? var.image_repo_name : "UNSET"}"
      },
      {
        "name"  = "IMAGE_TAG"
        "value" = "${signum(length(var.image_tag)) == 1 ? var.image_tag : "latest"}"
      },
      {
        "name"  = "STAGE"
        "value" = "${signum(length(var.stage)) == 1 ? var.stage : "UNSET"}"
      },
      {
        "name"  = "GITHUB_TOKEN"
        "value" = "${signum(length(var.github_token)) == 1 ? var.github_token : "UNSET"}"
      },
      "${var.environment_variables}",
    ]
  }

  source {
    buildspec           = "${var.buildspec}"
    type                = "${var.source_type}"
    location            = "${var.source_location}"
    git_clone_depth     = "${var.git_clone_depth}"
    report_build_status = "${var.report_build_status}"
  }

  tags = "${module.label.tags}"
}
