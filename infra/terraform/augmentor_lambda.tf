resource "aws_lambda_function" "augmentor" {
    function_name       = "augmentor"
    role                = aws_iam_role.augmentor_lambda_role.arn
    handler             = "augmentor.lambda_handler"
    runtime             = "python3.12"

    filename            = "${path.module}/tmp/lambda/augmentor.zip"
    source_code_hash    = filebase64sha256("${path.module}/tmp/lambda/augmentor.zip")

    timeout             = 30
    memory_size         = 128
}

# user & policy - cloudwatch, assume roles in customer accounts that start with "SixSevenLabs", push to kinesis, secretsmanager read
resource "aws_iam_role" "augmentor_lambda_role" {
    name = "augmentor-lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = { Service = "lambda.amazonaws.com" }
                Action    = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy" "augmentor_lambda_policy" {
    name = "augmentor-lambda-policy"
    role = aws_iam_role.augmentor_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid    = "CloudWatchLogs"
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ]
                Resource = aws_cloudwatch_log_group.augmentor_lambda_logs.arn
            },
            {
                Sid    = "AssumeCustomerRoles"
                Effect = "Allow"
                Action = "sts:AssumeRole"
                # allow assuming any role that starts with "SixSevenLabs" in any account
                Resource = "arn:aws:iam::*:role/SixSevenLabs*"
            },
            {
                Sid    = "KinesisPutRecords"
                Effect = "Allow"
                Action = ["kinesis:PutRecords", "kinesis:PutRecord"]
                Resource = aws_kinesis_stream.augmentor_stream.arn
            },
            {
                Sid    = "ReadPostgresSecret"
                Effect = "Allow"
                Action = ["secretsmanager:GetSecretValue"]
                Resource = aws_secretsmanager_secret.postgres_credentials.arn
            }
        ]
    })
}

resource "aws_cloudwatch_log_group" "augmentor_lambda_logs" {
    name              = "/aws/lambda/${aws_lambda_function.augmentor.function_name}"
    retention_in_days = 7
}