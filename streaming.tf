data "archive_file" "streaming" {
  type        = "zip"
  output_path = "/tmp/lambda-streaming-${random_id.id.hex}.zip"
  source {
    content  = <<EOF
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import {pipeline} from "node:stream/promises";

export const handler = awslambda.streamifyResponse(async (event, responseStream) => {
console.log(JSON.stringify(event, undefined, 4))
	const file = event.rawPath.match(/^.*\/(?<file>[^/]*)$/).groups.file;
	console.log("file", file);
	const client = new S3Client();
	const res = await client.send(new GetObjectCommand({
		Bucket: process.env.Bucket,
		Key: file,
	}));

  await pipeline(res.Body, awslambda.HttpResponseStream.from(responseStream, {
		statusCode: 200,
		headers: {
			"Cache-control": "no-store",
			"Content-Type": res.ContentType,
		},
		cookies: ["testcookie=value"],
	}));
});
EOF
    filename = "main.mjs"
  }
}

resource "aws_lambda_function" "streaming" {
  function_name    = "streaming-${random_id.id.hex}"
  filename         = data.archive_file.streaming.output_path
  source_code_hash = data.archive_file.streaming.output_base64sha256
  environment {
    variables = {
      Bucket : aws_s3_bucket.files.bucket,
    }
  }
  timeout = 30
  handler = "main.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.streaming.arn
}

resource "aws_cloudwatch_log_group" "streaming" {
  name              = "/aws/lambda/${aws_lambda_function.streaming.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function_url" "streaming" {
  function_name      = aws_lambda_function.streaming.function_name
  authorization_type = "NONE"
	invoke_mode = "RESPONSE_STREAM"
}

data "aws_iam_policy_document" "streaming" {
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

resource "aws_iam_role_policy" "streaming" {
  role   = aws_iam_role.streaming.id
  policy = data.aws_iam_policy_document.streaming.json
}
resource "aws_iam_role" "streaming" {
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


