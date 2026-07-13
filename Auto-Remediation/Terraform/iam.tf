resource "aws_iam_policy" "lambda_boundary" {

  name = "lambda-permission-boundary"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "s3:*",
          "iam:*",
          "logs:*",
          "sns:Publish"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_execution_role" {

  name = "vaultcloud-lambda-role"

  permissions_boundary = aws_iam_policy.lambda_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_logs" {

  role = aws_iam_role.lambda_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}