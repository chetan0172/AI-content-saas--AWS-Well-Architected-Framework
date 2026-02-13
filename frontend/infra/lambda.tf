# 1. Zip the Python code automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/worker"
  output_path = "${path.module}/worker.zip"
}

# 2. IAM Role (Identity: Who is this Lambda?)
resource "aws_iam_role" "lambda_role" {
  name = "ai_saas_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. Permissions (What can it do?)
# Allow writing logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow reading from SQS
resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# 4. The Lambda Function itself
resource "aws_lambda_function" "ai_worker" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ai-saas-worker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30 # Give it 30 seconds to run
}

# 5. The Trigger (SQS -> Lambda)
# This is the magic link. SQS will PUSH events to Lambda.
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.job_queue.arn
  function_name    = aws_lambda_function.ai_worker.arn
  batch_size       = 1 # Process 1 file at a time (simpler for now)
}