# Comparison of Lambda buffered vs streaming responses

## Deploy

* ```terraform init```
* ```terraform apply```

## Usage

The stack outputs 6 URLs, a buffered and a streaming implementation for 3 files of increasig sizes:

* small: 0.2 MB
* medium: 4.4 MB
* large: 13.8 MB

## Cleanup

* ```terraform destroy```
