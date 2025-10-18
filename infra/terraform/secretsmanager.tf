resource "aws_secretsmanager_secret" "postgres_credentials" {
    name                    = "augmentor-postgres-credentials"
    recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "postgres_credentials" {
    secret_id = aws_secretsmanager_secret.postgres_credentials.id
    secret_string = jsonencode({
        username = var.postgres_user
        password = var.postgres_password
        host     = var.postgres_host
        port     = var.postgres_port
        database = var.postgres_db
    })
}