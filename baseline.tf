data "archive_file" "baseline" {
  type        = "zip"
  output_path = "/tmp/lambda-baseline-${random_id.id.hex}.zip"
  source {
    content  = <<EOF
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { buffer } from "node:stream/consumers";

export const handler = async (event) => {
	const file = event.rawPath.match(/^.*\/(?<file>[^/]*)$/).groups.file;
	console.log("file", file);
	const client = new S3Client();
	const res = await client.send(new GetObjectCommand({
		Bucket: process.env.Bucket,
		Key: file,
	}));
	return {
		statusCode: 200,
		headers: {
			"Cache-control": "no-store",
			"Content-Type": res.ContentType,
		},
		cookies: ["testcookie=value"],
		body: (await buffer(res.Body)).toString("base64"),
		isBase64Encoded: true,
	};
}
EOF
    filename = "main.mjs"
  }
}

resource "aws_lambda_function" "baseline" {
  function_name    = "baseline-${random_id.id.hex}"
  filename         = data.archive_file.baseline.output_path
  source_code_hash = data.archive_file.baseline.output_base64sha256
  environment {
    variables = {
      Bucket : aws_s3_bucket.files.bucket,
    }
  }
  timeout = 30
  handler = "main.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.baseline.arn
}

resource "aws_cloudwatch_log_group" "baseline" {
  name              = "/aws/lambda/${aws_lambda_function.baseline.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function_url" "baseline" {
  function_name      = aws_lambda_function.baseline.function_name
  authorization_type = "NONE"
}

data "aws_iam_policy_document" "baseline" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.files.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "baseline" {
  role   = aws_iam_role.baseline.id
  policy = data.aws_iam_policy_document.baseline.json
}
resource "aws_iam_role" "baseline" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

