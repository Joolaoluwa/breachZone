locals {

  lambda_functions = [
    "config_dispatcher"
  ]

}


data "archive_file" "lambda_zip" {

  for_each = toset(local.lambda_functions)

  type = "zip"

  source_file = "../lambdas/${each.value}.py"

  output_path = "../build/${each.value}.zip"

}


resource "aws_lambda_function" "lambda" {

  for_each = toset(local.lambda_functions)


  function_name = "vaultcloud-${each.value}"


  role = aws_iam_role.lambda_execution_role.arn


  runtime = "python3.12"


  handler = "${each.value}.lambda_handler"


  filename = data.archive_file.lambda_zip[each.value].output_path


  source_code_hash = data.archive_file.lambda_zip[each.value].output_base64sha256


  timeout = 60


  memory_size = 256

}