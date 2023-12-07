data "archive_file" "lambda_function_file" {
  type = "zip"
  source_file = "upload/index.py"
  output_path = "${path.module}/upload/lambda_function.zip"
}

data "archive_file" "get_object_function_file" {
  type = "zip"
  source_file = "retrieve/index.py"
  output_path = "${path.module}/retrieve/lambda_function.zip"
}

resource "aws_lambda_function" "get_object" {
  provider = aws.default
  filename      = "${data.archive_file.get_object_function_file.output_path}"
  function_name = "getobjectfunction"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout       = 30
  publish       = true

  environment {
    variables = {
      REGION      = var.aws_default_region,
      BUCKET_NAME = aws_s3_bucket.timestamp_bucket.id,
      KMS_KEY_ID  = aws_kms_key.timestamp_key.key_id,
    }
  }

  depends_on = [ aws_kms_key.timestamp_key, aws_iam_role.lambda_exec_role]
}

resource "aws_lambda_function" "timestamp_uploader_lambda" {
  provider = aws.default
  filename      = "${data.archive_file.lambda_function_file.output_path}"
  function_name = "timestampUploaderLambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout       = 30
  publish       = true

  environment {
    variables = {
      REGION      = var.aws_default_region,
      BUCKET_NAME = aws_s3_bucket.timestamp_bucket.id,
      KMS_KEY_ID  = aws_kms_key.timestamp_key.key_id,
    }
  }

  depends_on = [ aws_kms_key.timestamp_key, aws_iam_role.lambda_exec_role]
}



resource "aws_iam_role" "lambda_exec_role" {
  provider = aws.default
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_s3_policy" {
  provider = aws.default
  name        = "LambdaS3AccessPolicy"
  description = "Policy to allow Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:ListObject*",
          "s3:PutObject",
          "s3:GetObject*",
          "s3:GetBucketLocation",
        ],
        Resource = [
          "${aws_s3_bucket.timestamp_bucket.arn}",
          "${aws_s3_bucket.timestamp_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "kms:Encrypt",
          "kms:Decrypt",
        ],
        Resource = "${aws_kms_key.timestamp_key.arn}"
      },
      {
        Effect    = "Allow",
        Action    = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource  = "arn:aws:logs:*:*:*",
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda" {
  provider = aws.default
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_s3_bucket" "timestamp_bucket" {
  provider = aws.default
  bucket = "${var.aws_default_region}-azeez-adeniyi-assessment"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "source" {
  provider = aws.default
  bucket = aws_s3_bucket.timestamp_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "replication_bucket" {
  provider = aws.east
  bucket = "us-east-1-destination-bucket-azeez"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "destination" {
  provider = aws.east
  bucket = aws_s3_bucket.replication_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create IAM role for replication
resource "aws_iam_role" "replication_role" {
  provider = aws.default
  name = "ReplicationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      },
      Action = "sts:AssumeRole",
    }
    ],
  })
}




resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.default
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.source, aws_s3_bucket_versioning.destination]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.timestamp_bucket.id

  rule {
    id = "EntireBucket"

    filter {
      prefix = ""
    }

    delete_marker_replication {
      status = "Disabled"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replication_bucket.arn
      storage_class = "DEEP_ARCHIVE" #deep archive for storage cost savings
    }
  }
}


# Attach policy allowing replication to the IAM role
resource "aws_iam_policy_attachment" "replication_policy_attachment" {
  provider = aws.default
  name       = "ReplicationPolicyAttachment"
  roles      = [aws_iam_role.replication_role.name]
  policy_arn = aws_iam_policy.replication.arn
}

data "aws_iam_policy_document" "replication" {
  provider = aws.default
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.timestamp_bucket.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.timestamp_bucket.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.replication_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "replication" {
  provider = aws.default
  name   = "tf-iam-role-policy-replication"
  policy = data.aws_iam_policy_document.replication.json
}



# Just for cost savings
resource "aws_s3_bucket_lifecycle_configuration" "storage_cost" {
  provider = aws.default
  bucket = aws_s3_bucket.timestamp_bucket.id
  rule {
    id = "rule-1"
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
    status = "Enabled"
  }
}

resource "aws_kms_key" "timestamp_key" {
  provider = aws.default
  description             = "KMS key for timestamp encryption"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_event_rule" "invoke_lambda_every_10_minutes" {
  provider = aws.default
  name                = "InvokeLambdaEvery10Minutes"
  description         = "Trigger Lambda function every 10 minutes"
  schedule_expression = "rate(10 minutes)"  # Schedule Lambda execution every 10 minutes
}

resource "aws_cloudwatch_event_target" "invoke_lambda_target" {
  provider = aws.default
  rule      = aws_cloudwatch_event_rule.invoke_lambda_every_10_minutes.name
  target_id = "InvokeLambdaTarget"
  arn       = aws_lambda_function.timestamp_uploader_lambda.arn
}

resource "aws_lambda_permission" "allow_lambda_trigger" {
    provider = aws.default
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.timestamp_uploader_lambda.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.invoke_lambda_every_10_minutes.arn
}

resource "aws_apigatewayv2_api" "lambda" {
  provider = aws.default
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  provider = aws.default
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "timestamp" {
  provider = aws.default
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_object.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  provider = aws.default
  api_id = aws_apigatewayv2_api.lambda.id
 
  route_key = "GET /timestamp" #routing to /timestamp
  target    = "integrations/${aws_apigatewayv2_integration.timestamp.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  provider = aws.default
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  provider = aws.default
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_object.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
