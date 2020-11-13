variable "unique_name" {
  type        = string
  description = "A unique name for this application (e.g. mlflow-team-name)"
}

variable "api_id" {
  type        = string
  description = "target apigateway id"
}

variable "secret_id" {
  type        = string
  description = "authentication secret id by secrets manager"
}
