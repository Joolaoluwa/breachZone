#!/usr/bin/env bash
#
# VaultCloud Terraform backend bootstrap
# Creates the S3 bucket + DynamoDB lock table used by ALL domain state files,
# then generates a backend.tf in each environments/breach-zone/<domain> folder.
#
# Safe to re-run: checks for existing resources before creating.

set -euo pipefail

# ---- Config — edit these if needed ----
BUCKET_NAME="vaultcloud-tfstate"
DYNAMODB_TABLE="vaultcloud-tf-locks"
REGION="us-east-1"
ENV_ROOT="environments/breach-zone"
DOMAINS=("zero-trust" "cspm" "vuln-mgmt" "auto-remediation" "threat-detection")
# ----------------------------------------

echo "== Step 1/5: Checking/creating S3 bucket: ${BUCKET_NAME} =="
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "Bucket already exists, skipping creation."
else
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  echo "Bucket created."
fi

echo "== Step 2/5: Enabling versioning, encryption, and public access block =="
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "== Step 3/5: Checking/creating DynamoDB lock table: ${DYNAMODB_TABLE} =="
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Table already exists, skipping creation."
else
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
  echo "Table created."
fi

echo "== Step 4/5: Generating backend.tf for each domain =="
for domain in "${DOMAINS[@]}"; do
  target_dir="${ENV_ROOT}/${domain}"
  mkdir -p "${target_dir}"
  cat > "${target_dir}/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "breach-zone/${domain}/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
  }
}
EOF
  echo "  -> ${target_dir}/backend.tf"
done

echo "== Step 5/5: Verification =="
aws s3api head-bucket --bucket "${BUCKET_NAME}" && echo "Bucket OK: ${BUCKET_NAME}"
aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" \
  --query "Table.TableStatus" --output text | xargs -I{} echo "Table OK: ${DYNAMODB_TABLE} (status: {})"

echo ""
echo "Bootstrap complete. Next: cd into each domain folder and run 'terraform init'."