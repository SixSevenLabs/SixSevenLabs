resource "aws_lambda_function" "master" {
    function_name       = "master"
    role                = aws_iam_role.master_lambda_role.arn
    handler             = "bootstrap"
    runtime             = "provided.al2023"

    filename            = "${path.module}/tmp/lambda/master.zip"
    source_code_hash    = filebase64sha256("${path.module}/tmp/lambda/master.zip")

    timeout             = 30
    memory_size         = 128
}

# user & policy - cloudwatch, assume roles in customer accounts that start with "SixSevenLabs", read from secretsmanager
resource "aws_iam_role" "master_lambda_role" {
    name = "master-lambda-role"

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

resource "aws_iam_role_policy" "master_lambda_policy" {
    name = "master-lambda-policy"
    role = aws_iam_role.master_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid    = "CloudWatchLogsPolicy"
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ]
                Resource = aws_cloudwatch_log_group.master_lambda_logs.arn
            },
            {
                Sid    = "AssumeCustomerRoles"
                Effect = "Allow"
                Action = "sts:AssumeRole"
                Resource = "arn:aws:iam::*:role/SixSevenLabs*"
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

resource "aws_cloudwatch_log_group" "master_lambda_logs" {
    name              = "/aws/lambda/${aws_lambda_function.master.function_name}"
    retention_in_days = 7
}