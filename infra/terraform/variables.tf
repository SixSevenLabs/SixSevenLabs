variable "postgres_user" {
    description = "Postgres user"
    type        = string
}

variable "postgres_password" {
    description = "Postgres password"
    type        = string
    sensitive   = true
}

variable "postgres_host" {
    description = "Postgres host"
    type        = string
}

variable "postgres_port" {
    description = "Postgres port"
    type        = number
    default     = 5432
}

variable "postgres_db" {
    description = "Postgres database name"
    type        = string
}