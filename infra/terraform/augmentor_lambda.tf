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

# user - has permission to assume customer lambda roles
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

# policy - write logs to cloudwatch
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
                Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/augmentor*"
            },
            {
                Sid    = "AssumeCustomerRoles"
                Effect = "Allow"
                Action = "sts:AssumeRole"
                # allow assuming any role that starts with "SixSevenLabs" in any account
                Resource = "arn:aws:iam::*:role/SixSevenLabs*"
            }
        ]
    })
}