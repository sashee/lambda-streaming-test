data "archive_file" "init-data" {
  type        = "zip"
  output_path = "/tmp/lambda-init-data-${random_id.id.hex}.zip"
  source {
    content  = <<EOF
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

export const handler = async (event) => {
	const files = [
		{name: "file1", url: "https://unsplash.com/photos/sqJ40H9RtNw/download?w=1000", "size": "0.2 MB", "contentType": "image/jpeg"},
		{name: "file2", url: "https://unsplash.com/photos/qOaeVSKyhhE/download", "size": "4.4 MB", "contentType": "image/jpeg"},
		{name: "file3", url: "https://github.com/bower-media-samples/big-buck-bunny-1080p-60fps-30s/raw/master/video.mp4", "size": "13.8 MB", "contentType":
"video/mp4"},
	];
	const client = new S3Client();
	await Promise.all(files.map(async ({name, url, contentType}) => {
		const res = await fetch(url);
		const blob = await res.arrayBuffer();
		await client.send(new PutObjectCommand({
			Bucket: process.env.Bucket,
			Key: name,
			Body: blob,
			ContentType: contentType,
		}));
	}));
}
EOF
    filename = "main.mjs"
  }
}

resource "aws_lambda_function" "init-data" {
  function_name    = "init-data-${random_id.id.hex}"
  filename         = data.archive_file.init-data.output_path
  source_code_hash = data.archive_file.init-data.output_base64sha256
  environment {
    variables = {
      Bucket : aws_s3_bucket.files.bucket,
    }
  }
  timeout = 300
  handler = "main.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.init-data.arn
}

resource "aws_lambda_invocation" "init-data2" {
  function_name = aws_lambda_function.init-data.function_name

  input = "{}"
}

resource "aws_cloudwatch_log_group" "init-data" {
  name              = "/aws/lambda/${aws_lambda_function.init-data.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "init-data" {
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
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.files.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "init-data" {
  role   = aws_iam_role.init-data.id
  policy = data.aws_iam_policy_document.init-data.json
}
resource "aws_iam_role" "init-data" {
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
