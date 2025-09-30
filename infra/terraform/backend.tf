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