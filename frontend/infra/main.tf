provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. NETWORKING (VPC) - RESTORED!
# ==========================================
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "ai-saas-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
}

# ==========================================
# 2. CONTAINER REGISTRY (ECR) - RESTORED!
# ==========================================
resource "aws_ecr_repository" "backend_repo" {
  name         = "ai-saas-backend"
  force_delete = true
}

# ==========================================
# 3. STORAGE (S3)
# ==========================================
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "uploads" {
  bucket        = "ai-saas-uploads-${random_id.bucket_id.hex}"
  force_destroy = true 
}

# ==========================================
# 4. MESSAGING (SQS)
# ==========================================
resource "aws_sqs_queue" "job_queue" {
  name                      = "ai-saas-jobs"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

# ==========================================
# 5. PERMISSIONS (IAM)
# ==========================================
resource "aws_iam_policy" "app_permissions" {
  name        = "ai-saas-app-permissions"
  description = "Allow ECS to talk to S3 and SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.job_queue.arn
      }
    ]
  })
}

# IMPORTANT: We use a string reference here to avoid circular dependency errors with ecs.tf
resource "aws_iam_role_policy_attachment" "ecs_app_permissions_attach" {
  role       = "ecs_task_execution_role"
  policy_arn = aws_iam_policy.app_permissions.arn
}

# ==========================================
# 6. OUTPUTS
# ==========================================
output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "sqs_queue_url" {
  value = aws_sqs_queue.job_queue.id
}

output "ecr_repo_url" {
  value = aws_ecr_repository.backend_repo.repository_url
}