output "storage_gateway_id" {
  description = "ID of the managed Storage Gateway hybrid service endpoint."
  value       = aws_storagegateway_gateway.hybrid_gateway.gateway_id
}

output "cloud_storage_bucket" {
  description = "S3 bucket backing the hybrid storage, with a lifecycle rule to Glacier."
  value       = aws_s3_bucket.cloud_storage.bucket
}

output "elastic_volume_id" {
  description = "ID of the EBS elastic volume."
  value       = aws_ebs_volume.elastic_volume.id
}

output "shared_storage_efs_id" {
  description = "ID of the EFS shared file system."
  value       = aws_efs_file_system.shared_storage.id
}

output "vpn_connection_id" {
  description = "ID of the Site-to-Site VPN connection linking on-premises to the VPC."
  value       = aws_vpn_connection.main.id
}

output "storage_alarms_topic_arn" {
  description = "ARN of the SNS topic notified on storage/backup alarms."
  value       = aws_sns_topic.storage_alarms.arn
}

output "backup_vault_name" {
  description = "Name of the AWS Backup vault protecting cloud storage resources."
  value       = aws_backup_vault.storage.name
}
