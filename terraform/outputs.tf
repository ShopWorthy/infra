output "db_endpoint" {
  value = aws_db_instance.shopworthy.endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.exports.bucket
}

output "instance_public_ip" {
  value = aws_instance.shopworthy.public_ip
}

output "app_url" {
  value = "http://${aws_instance.shopworthy.public_ip}:3000"
}
