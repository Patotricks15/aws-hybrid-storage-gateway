# ─── Networking: VPC hosting the Storage Gateway VPN endpoint ───────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "gateway" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-gateway-subnet" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt" })
}

resource "aws_route_table_association" "gateway" {
  subnet_id      = aws_subnet.gateway.id
  route_table_id = aws_route_table.main.id
}

# ─── Hybrid connectivity: Site-to-Site VPN linking on-premises to the VPC ────

resource "aws_customer_gateway" "on_premises" {
  bgp_asn    = 65000
  ip_address = var.on_premises_router_ip
  type       = "ipsec.1"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-on-prem-router" })
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vgw" })
}

resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.on_premises.id
  vpn_gateway_id       = aws_vpn_gateway.main.id
  type                 = "ipsec.1"
  static_routes_only   = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpn" })
}

# ─── Storage Services: S3 (with Glacier lifecycle), EBS, EFS ────────────────

resource "aws_s3_bucket" "cloud_storage" {
  bucket        = "${local.name_prefix}-cloud-storage-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "cloud_storage" {
  bucket = aws_s3_bucket.cloud_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloud_storage" {
  bucket = aws_s3_bucket.cloud_storage.id

  rule {
    id     = "archive-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

resource "aws_ebs_volume" "elastic_volume" {
  availability_zone = "${var.aws_region}a"
  size              = 100
  type              = "gp3"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-elastic-volume" })
}

resource "aws_efs_file_system" "shared_storage" {
  encrypted = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-shared-storage" })
}

resource "aws_efs_mount_target" "shared_storage" {
  file_system_id  = aws_efs_file_system.shared_storage.id
  subnet_id       = aws_subnet.gateway.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${local.name_prefix}-efs-sg"
  description = "Allow NFS traffic from the gateway subnet to EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ─── Storage Gateway: managed hybrid storage service, backed by S3 ──────────

resource "aws_storagegateway_gateway" "hybrid_gateway" {
  gateway_name       = "${local.name_prefix}-gateway"
  gateway_timezone   = "GMT"
  gateway_type       = "FILE_S3"
  # In production this activation key comes from the on-premises appliance's
  # local web console after it registers with this managed service endpoint.
  gateway_ip_address = var.on_premises_router_ip

  tags = local.common_tags
}

# ─── Management and Monitoring: CloudWatch alarm + SNS + AWS Backup ─────────

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/floci/${local.name_prefix}/storage-gateway"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_sns_topic" "storage_alarms" {
  name = "${local.name_prefix}-storage-alarms"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.storage_alarms.arn
  protocol  = "email"
  endpoint  = var.ops_notification_email
}

resource "aws_cloudwatch_metric_alarm" "cache_hit_percent" {
  alarm_name          = "${local.name_prefix}-low-cache-hit-percent"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CacheHitPercent"
  namespace           = "AWS/StorageGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerts when the Storage Gateway local cache hit rate degrades."
  alarm_actions       = [aws_sns_topic.storage_alarms.arn]

  dimensions = {
    GatewayId = aws_storagegateway_gateway.hybrid_gateway.gateway_id
  }

  tags = local.common_tags
}

resource "aws_backup_vault" "storage" {
  name = "${local.name_prefix}-backup-vault"

  tags = local.common_tags
}

resource "aws_iam_role" "backup" {
  name = "${local.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "storage" {
  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.storage.name
    schedule          = "cron(0 5 * * ? *)"
  }

  tags = local.common_tags
}

resource "aws_backup_selection" "storage" {
  name         = "${local.name_prefix}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.storage.id

  resources = [
    aws_s3_bucket.cloud_storage.arn,
    aws_ebs_volume.elastic_volume.arn,
  ]
}
