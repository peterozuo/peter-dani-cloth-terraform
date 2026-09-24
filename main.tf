# ============================================================
# PETER DANI CLOTH
# Production-Style Serverless Infrastructure
# AWS Region: us-east-1
# Managed with Terraform
# ============================================================


# ============================================================
# 1. AWS PROVIDER
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


# ============================================================
# 2. S3 BUCKET
# Frontend files: HTML, CSS, JavaScript
# ============================================================

resource "aws_s3_bucket" "frontend" {

  bucket = "${var.project_name}-${var.environment}-frontend"

  tags = {
    Name        = "${var.project_name}-frontend"
    Environment = var.environment
  }
}


# Prevent public access to the bucket
resource "aws_s3_bucket_public_access_block" "frontend" {

  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Disable ACLs and make bucket ownership controlled by the bucket owner
resource "aws_s3_bucket_ownership_controls" "frontend" {

  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


# ============================================================
# 3. CLOUDFRONT
# Delivers the frontend globally
# ============================================================

resource "aws_cloudfront_origin_access_control" "frontend" {

  name                              = "${var.project_name}-oac"
  description                       = "CloudFront access to private S3 frontend"
  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  signing_protocol = "sigv4"
}


resource "aws_cloudfront_distribution" "frontend" {

  enabled             = true
  default_root_object = "index.html"

  origin {

    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name

    origin_id = "S3-${aws_s3_bucket.frontend.id}"

    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }


  default_cache_behavior {

    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {

      query_string = false

      cookies {
        forward = "none"
      }
    }
  }


  restrictions {

    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  price_class = "PriceClass_100"


  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
  }
}


# ============================================================
# 4. S3 BUCKET POLICY
# Allow CloudFront to read the private bucket
# ============================================================

data "aws_iam_policy_document" "frontend_bucket_policy" {

  statement {

    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*"
    ]

    condition {

      test = "StringEquals"

      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.frontend.arn
      ]
    }
  }
}


resource "aws_s3_bucket_policy" "frontend" {

  bucket = aws_s3_bucket.frontend.id

  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}

# Upload website files to the S3 bucket 
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/website/index.html")
}

resource "aws_s3_object" "style" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "style.css"
  source       = "${path.module}/website/style.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/website/style.css")
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "script.js"
  source       = "${path.module}/website/script.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/website/script.js")
}



# ============================================================
# 5. DYNAMODB
# Application database
# ============================================================

resource "aws_dynamodb_table" "app" {

  name = "${var.project_name}-${var.environment}"

  billing_mode = "PAY_PER_REQUEST"

  hash_key = "id"


  attribute {
    name = "id"
    type = "S"
  }


  tags = {
    Name        = "${var.project_name}-database"
    Environment = var.environment
  }
}


# ============================================================
# 6. IAM ROLE FOR LAMBDA
# Allows Lambda to assume this role
# ============================================================

resource "aws_iam_role" "lambda" {

  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ============================================================
# 7. LAMBDA CLOUDWATCH LOGGING PERMISSION
# ============================================================

resource "aws_iam_role_policy_attachment" "lambda_logs" {

  role = aws_iam_role.lambda.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ============================================================
# 8. LAMBDA DYNAMODB PERMISSIONS
# Least-privilege access to our DynamoDB table
# ============================================================

resource "aws_iam_role_policy" "lambda_dynamodb" {

  name = "${var.project_name}-dynamodb-access"

  role = aws_iam_role.lambda.id


  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan"

        ]

        Resource = aws_dynamodb_table.app.arn
      }
    ]
  })
}


# ============================================================
# 9. PACKAGE LAMBDA CODE
# The Python file will be inside:
#
# lambda/lambda_function.py
# ============================================================

data "archive_file" "lambda" {

  type = "zip"

  source_file = "${path.module}/lambda/lambda_function.py"

  output_path = "${path.module}/lambda_function.zip"
}


# ============================================================
# 10. LAMBDA FUNCTION
# Backend business logic
# ============================================================

resource "aws_lambda_function" "api" {

  function_name = "${var.project_name}-${var.environment}-api"

  role = aws_iam_role.lambda.arn

  runtime = var.lambda_runtime

  handler = "lambda_function.lambda_handler"


  filename = data.archive_file.lambda.output_path

  source_code_hash = data.archive_file.lambda.output_base64sha256


  timeout = 10

  memory_size = 128


  environment {

    variables = {

      TABLE_NAME = aws_dynamodb_table.app.name
    }
  }


  tags = {

    Name        = "${var.project_name}-api"
    Environment = var.environment
  }


  depends_on = [

    aws_iam_role_policy_attachment.lambda_logs,

    aws_iam_role_policy.lambda_dynamodb

  ]
}


# ============================================================
# 11. API GATEWAY
# HTTP API entry point for the backend
# ============================================================

resource "aws_apigatewayv2_api" "api" {

  name = "${var.project_name}-${var.environment}-api"

  protocol_type = "HTTP"


  cors_configuration {

    allow_origins = [
      "*"
    ]

    allow_methods = [
      "GET"
    ]

    allow_headers = [
      "*"
    ]
  }


  tags = {

    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}


# ============================================================
# 12. API GATEWAY → LAMBDA INTEGRATION
# ============================================================

resource "aws_apigatewayv2_integration" "lambda" {

  api_id = aws_apigatewayv2_api.api.id

  integration_type = "AWS_PROXY"

  integration_uri = aws_lambda_function.api.invoke_arn

  payload_format_version = "2.0"
}


# ============================================================
# 13. API ROUTE
#
# GET /hello
# ============================================================

resource "aws_apigatewayv2_route" "hello" {

  api_id = aws_apigatewayv2_api.api.id

  route_key = "GET /hello"

  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}


# ============================================================
# 14. API GATEWAY STAGE
# ============================================================

resource "aws_apigatewayv2_stage" "production" {

  api_id = aws_apigatewayv2_api.api.id

  name = "production"

  auto_deploy = true
}


# ============================================================
# 15. ALLOW API GATEWAY TO INVOKE LAMBDA
# ============================================================

resource "aws_lambda_permission" "api_gateway" {

  statement_id = "AllowAPIGatewayInvoke"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.api.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}


# ============================================================
# 16. SNS TOPIC
# Receives CloudWatch alerts
# ============================================================

resource "aws_sns_topic" "alerts" {

  name = "${var.project_name}-${var.environment}-alerts"


  tags = {

    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}


# ============================================================
# 17. CLOUDWATCH ALARM
# Detect Lambda errors
# ============================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {

  alarm_name = "${var.project_name}-${var.environment}-lambda-errors"

  alarm_description = "Alerts when the Peter Dani Cloth Lambda function encounters errors."


  namespace = "AWS/Lambda"

  metric_name = "Errors"


  dimensions = {

    FunctionName = aws_lambda_function.api.function_name
  }


  statistic = "Sum"

  period = 60

  evaluation_periods = 1

  threshold = 1


  comparison_operator = "GreaterThanOrEqualToThreshold"


  treat_missing_data = "notBreaching"


  alarm_actions = [

    aws_sns_topic.alerts.arn
  ]


  tags = {

    Name        = "${var.project_name}-lambda-error-alarm"
    Environment = var.environment
  }
}