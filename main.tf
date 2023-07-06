resource "random_id" "id" {
  byte_length = 8
}

resource "aws_s3_bucket" "files" {
  force_destroy = "true"
}

output "small_buffered" {
	value = "${aws_lambda_function_url.baseline.function_url}file1"
}

output "small_streaming" {
	value = "${aws_lambda_function_url.streaming.function_url}file1"
}

output "medium_buffered" {
	value = "${aws_lambda_function_url.baseline.function_url}file2"
}

output "medium_streaming" {
	value = "${aws_lambda_function_url.streaming.function_url}file2"
}

output "large_buffered" {
	value = "${aws_lambda_function_url.baseline.function_url}file3"
}

output "large_streaming" {
	value = "${aws_lambda_function_url.streaming.function_url}file3"
}

