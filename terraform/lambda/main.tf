
data "aws_caller_identity" "this" {}

data "aws_region" "this" {}


module "lambda_function_container_image" {
  architectures = ["x86_64"]
  version       = "3.3.1"
  source        = "terraform-aws-modules/lambda/aws"

  function_name = "my-lambda-existing-package-local"
  description   = "My awesome lambda function"

  create_package = false

  image_uri    = "${data.aws_caller_identity.this.account_id}.dkr.ecr.${data.aws_region.this.name}.amazonaws.com/nix:latest"
  package_type = "Image"

  create_lambda_function_url = true
}
