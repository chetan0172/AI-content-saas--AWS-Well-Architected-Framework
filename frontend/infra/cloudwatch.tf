resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "AI-Content-SaaS-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: ECS Cluster Health (CPU & Memory)
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "ai-saas-backend-service", "ClusterName", "ai-saas-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Load (CPU/Memory)"
          period  = 60
        }
      },
      
      # Row 1: SQS Queue Depth (The "Backlog")
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "ai-saas-jobs"],
            [".", "ApproximateNumberOfMessagesNotVisible", ".", "."] # Messages currently being processed
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Job Queue Depth (Backlog)"
          period  = 60
        }
      },

      # Row 2: Lambda Worker Performance
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations","FunctionName", aws_lambda_function.ai_worker.function_name],
            [".", "Errors", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Worker Activity (Invocations vs Errors)"
          period  = 60
        }
      }
    ]
  })
}