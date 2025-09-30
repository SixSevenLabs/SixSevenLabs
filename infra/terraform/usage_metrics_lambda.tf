data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# lambda to consume usage metrics from the kinesis stream
# note - ensure that the Go binary is called 'bootstrap'; Lambda expects this for custom runtimes
# note - every Go Lambda just has to call lambda.Start() in main()
resource "aws_lambda_function" "augmentor_usage_metrics_consumer" {
    function_name = "augmentor-usage-metrics-consumer"
    role          = aws_iam_role.augmentor_usage_metrics_lambda_role.arn
    handler       = "bootstrap"
    runtime       = "provided.al2023"

    filename         = "${path.module}/lambda/augmentor_usage_metrics_consumer.zip"
    source_code_hash = filebase64sha256("${path.module}/tmp/lambda/augmentor_usage_metrics_consumer.zip")

    timeout     = 30
    memory_size = 128

    environment {
        variables = {
            TABLE_NAME = aws_dynamodb_table.metrics_table.name
        }
    }
}

# user and policy for lambda to...
# 1. consume usage metrics from the kinesis stream
# 2. write logs to cloudwatch
resource "aws_iam_role" "augmentor_usage_metrics_lambda_role" {
    name = "augmentor-usage-metrics-lambda-role"

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

resource "aws_iam_role_policy" "augmentor_usage_metrics_lambda_policy" {
    name = "augmentor-usage-metrics-lambda-policy"
    role = aws_iam_role.augmentor_usage_metrics_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid    = "ReadKinesis"
                Effect = "Allow"
                Action = [
                    "kinesis:DescribeStream",
                    "kinesis:GetShardIterator",
                    "kinesis:GetRecords",
                    "kinesis:ListShards"
                ]
                Resource = aws_kinesis_stream.augmentor_usage_metrics_stream.arn
            },
            {
                Sid    = "WriteLogs"
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ]
                Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
            }
        ]
    })
}

# bind kinesis stream to lambda
resource "aws_lambda_event_source_mapping" "augmentor_usage_metrics_stream_mapping" {
    event_source_arn  = aws_kinesis_stream.augmentor_usage_metrics_stream.arn
    function_name     = aws_lambda_function.augmentor_usage_metrics_consumer.arn
    starting_position = "LATEST"
    batch_size        = 100
    maximum_batching_window_in_seconds = 5
}

# cloudwatch log group for the lambda
resource "aws_cloudwatch_log_group" "augmentor_usage_metrics_lambda_logs" {
    name              = "/aws/lambda/${aws_lambda_function.augmentor_usage_metrics_consumer.function_name}"
    retention_in_days = 14
}