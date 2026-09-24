output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.production.invoke_url
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.app.name
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}