provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "config_bucket" {
  bucket = "vaultcloud-config-snapshots"
}

resource "aws_s3_bucket_public_access_block" "config_bucket" {
  bucket                  = aws_s3_bucket.config_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config_role" {
  name = "vaultcloud-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config_bucket.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config_bucket.arn}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "recorder" {
  name     = "vaultcloud-recorder"
  role_arn = aws_iam_role.config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "channel" {
  name           = "vaultcloud-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
  depends_on     = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_configuration_recorder_status" "recorder_status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.channel]
}

resource "aws_config_config_rule" "public_s3" {
  name       = "s3-bucket-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "open_sg" {
  name       = "restricted-ssh"
  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "unencrypted_ebs" {
  name       = "encrypted-volumes"
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "root_mfa" {
  name       = "root-account-mfa-enabled"
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "cloudtrail_logging" {
  name       = "cloudtrail-enabled"
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "key_rotation" {
  name       = "cmk-backing-key-rotation-enabled"
  source {
    owner             = "AWS"
    source_identifier = "CMK_BACKING_KEY_ROTATION_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "public_snapshots" {
  name       = "ebs-snapshot-public-restorable-check"
  source {
    owner             = "AWS"
    source_identifier = "EBS_SNAPSHOT_PUBLIC_RESTORABLE_CHECK"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "overprivileged_roles" {
  name       = "iam-policy-no-statements-with-admin-access"
  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_cloudwatch_log_group" "config_event_test" {
  name              = "/vaultcloud/config-event-test"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_rule" "test_compliance_change" {
  name = "vaultcloud-test-compliance-change"
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
  })
}

resource "aws_cloudwatch_event_target" "log_target" {
  rule = aws_cloudwatch_event_rule.test_compliance_change.name
  arn  = aws_cloudwatch_log_group.config_event_test.arn
}

resource "aws_cloudwatch_log_resource_policy" "allow_eventbridge" {
  policy_name = "allow-eventbridge-to-cwl"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgeToCloudWatchLogs"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "logs:PutLogEvents"
      Resource  = "${aws_cloudwatch_log_group.config_event_test.arn}:*"
    }]
  })
}