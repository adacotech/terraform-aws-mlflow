data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "db_password" {
  name = var.database_password_secret_arn
}

resource "aws_iam_role_policy" "db_secrets" {
  name = "${var.unique_name}-read-db-pass-secret"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
        ]
        Resource = [
          data.aws_ssm_parameter.db_password.arn,
        ]
      },
    ]
  })
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.unique_name}-rds"
  subnet_ids = var.database_subnet_ids
}

resource "aws_security_group" "rds" {
  name   = "${var.unique_name}-rds"
  vpc_id = var.vpc_id
  tags   = local.tags

  ingress {
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "backend_store" {
  identifier                = var.unique_name
  tags                      = local.tags
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = var.database_instance_class
  port                      = local.db_port
  multi_az                  = var.rds_is_multi_az
  allocated_storage         = 50
  max_allocated_storage     = 2000
  db_subnet_group_name      = aws_db_subnet_group.rds.name
  vpc_security_group_ids    = [aws_security_group.rds.id]
  username                  = "admin"
  name                      = "mlflow"
  skip_final_snapshot       = var.database_skip_final_snapshot
  final_snapshot_identifier = var.unique_name
  password                  = data.aws_ssm_parameter.db_password.value
  backup_retention_period   = 14
}
