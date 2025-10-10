# augmentor queue
resource "aws_sqs_queue" "augmentor_queue" {
    name                        = "augmentor-queue"
    visibility_timeout_seconds  = 30        # time before another consumer can process the msg if not deleted
    message_retention_seconds   = 1209600   # 14 days
}

# user and policy for frontend to send message to augmentor queue
resource "aws_iam_user" "frontend_sqs_sender" {
    name = "frontend-sqs-sender"
}

resource "aws_iam_user_policy" "frontend_sqs_sender_policy" {
    name = "frontend-sqs-sender-policy"
    user = aws_iam_user.frontend_sqs_sender.name

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid      = "AllowSendMessage"
                Effect   = "Allow"
                Action   = ["sqs:SendMessage"]
                Resource = aws_sqs_queue.augmentor_queue.arn
            }
        ]
    })
}

# access (key/secret) for frontend to be able to send to augmentor queue; this should be stored in secrets manager or similar
resource "aws_iam_access_key" "frontend_sqs_sender_key" {
    user = aws_iam_user.frontend_sqs_sender.name
}

# enforce that only the frontend user can send messages to the augmentor queue
resource "aws_sqs_queue_policy" "augmentor_queue_acl" {
    queue_url = aws_sqs_queue.augmentor_queue.id

    policy = jsonencode({
        Version = "2012-10-17"
        Id      = "QueuePolicy"
        Statement = [
            {
                Sid       = "AllowFrontendUserSend"
                Effect    = "Allow"
                Principal = { AWS = aws_iam_user.frontend_sqs_sender.arn }
                Action    = ["sqs:SendMessage"]
                Resource  = aws_sqs_queue.augmentor_queue.arn
            },
            {
                Sid    = "DenyOthers"
                Effect = "Deny"
                Principal = "*"
                Action = "sqs:SendMessage"
                Resource = aws_sqs_queue.app_queue.arn
                Condition = {
                    StringNotEquals = {
                        "aws:PrincipalArn" = aws_iam_user.frontend_sqs_sender.arn
                    }
                }
            }
        ]
    })
}