terraform {
    backend "s3" {
        bucket         = "augmentor-state-bucket"
        key            = "augmentor/terraform.tfstate"
        region         = "us-east-1"
        encrypt        = true
        dynamodb_table = "augmentor-lock-table"
        profile        = "sixsevenlabs"
    }
}

# STRONG NOTE: encrypt=true enables server-side encryption IN TRANSIT but does NOT enable it at rest.
# so, we have to manually create the S3 bucket with encryption at rest enabled. VERY important!
# below is what terraform code would look like to create the S3 bucket w/ encryption at rest
# chicken-and-egg problem: you need a bucket to store state, but state is managed by Terraform, so manual creation is required
# resource "aws_s3_bucket" "augmentor_state_bucket" {
#     bucket = "augmentor-state-bucket"
# }
# resource "aws_s3_bucket_versioning" "augmentor_state_bucket_versioning" {
#     bucket = aws_s3_bucket.augmentor_state_bucket.id
#     versioning_configuration {
#         status = "Enabled"
#     }
# }
# resource "aws_s3_bucket_server_side_encryption_configuration" "augmentor_state_bucket_encryption" {
#     bucket = aws_s3_bucket.augmentor_state_bucket.id
#     rule {
#         apply_server_side_encryption_by_default {
#             sse_algorithm = "AES256"
#         }
#     }
# }