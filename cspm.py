import boto3
import json
from botocore.exceptions import ClientError

# Initialize color codes for clean CLI output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

class AWSPostureScanner:
    def __init__(self):
        try:
            self.session = boto3.Session()
            self.sts = self.session.client('sts')
            self.account_id = self.sts.get_caller_identity()['Account']
            print(f"Initialized Scanner for AWS Account: {self.account_id}\n" + "="*50)
        except Exception as e:
            print(f"{RED}Error initializing AWS session. Are your credentials set?{RESET}\n{e}")
            exit(1)

    def print_result(self, check_name, status, details):
        color = GREEN if status == "PASS" else RED
        print(f"[{color}{status}{RESET}] {check_name}")
        print(f"       Details: {details}\n")

    # 1. Public S3 Buckets
    def check_public_s3(self):
        s3 = self.session.client('s3')
        try:
            buckets = s3.list_buckets().get('Buckets', [])
            if not buckets:
                self.print_result("Public S3 Check", "PASS", "No S3 buckets found.")
                return

            for bucket in buckets:
                name = bucket['Name']
                try:
                    pabi = s3.get_public_access_block(Bucket=name)
                    config = pabi['PublicAccessBlockConfiguration']
                    if all([config['BlockPublicAcls'], config['IgnorePublicAcls'], 
                            config['BlockPublicPolicy'], config['RestrictPublicBuckets']]):
                        self.print_result(f"S3 Public Access Block: {name}", "PASS", "All public access blocks enabled.")
                    else:
                        self.print_result(f"S3 Public Access Block: {name}", "FAIL", "Some public access settings are disabled.")
                except ClientError as e:
                    if e.response['Error']['Code'] == 'NoSuchPublicAccessBlockConfiguration':
                        self.print_result(f"S3 Public Access Block: {name}", "FAIL", "No Public Access Block configuration exists!")
        except Exception as e:
            print(f"Error scanning S3: {e}")

    # 2. Open Security Groups (0.0.0.0/0 on sensitive ports)
    def check_open_security_groups(self):
        ec2 = self.session.client('ec2')
        try:
            sgs = ec2.describe_security_groups().get('SecurityGroups', [])
            for sg in sgs:
                sg_id = sg['GroupId']
                sg_name = sg['GroupName']
                for permission in sg.get('IpPermissions', []):
                    # Check if open to the world
                    is_public = any(ip.get('CidrIp') == '0.0.0.0/0' for ip in permission.get('IpRanges', []))
                    if is_public:
                        port_range = f"{permission.get('FromPort')}-{permission.get('ToPort')}"
                        self.print_result(f"SG Inbound Rule: {sg_id} ({sg_name})", "FAIL", f"Port {port_range} open to the world (0.0.0.0/0)!")
                        return
            self.print_result("Security Groups Check", "PASS", "No security groups broadly exposed to 0.0.0.0/0 found.")
        except Exception as e:
            print(f"Error scanning Security Groups: {e}")

    # 3. Unencrypted Storage (EBS Volumes)
    def check_unencrypted_ebs(self):
        ec2 = self.session.client('ec2')
        try:
            volumes = ec2.describe_volumes().get('Volumes', [])
            unencrypted_count = 0
            for vol in volumes:
                if not vol['Encrypted']:
                    unencrypted_count += 1
                    self.print_result(f"EBS Volume Encryption: {vol['VolumeId']}", "FAIL", "Volume is not encrypted.")
            if unencrypted_count == 0:
                self.print_result("EBS Encryption Check", "PASS", "All existing EBS volumes are encrypted.")
        except Exception as e:
            print(f"Error scanning EBS: {e}")

    # 4. Root MFA Enabled
    def check_root_mfa(self):
        iam = self.session.client('iam')
        try:
            summary = iam.get_account_summary()['SummaryMap']
            if summary.get('AccountMFAEnabled', 0) == 1:
                self.print_result("Root Account MFA", "PASS", "MFA is enabled on the root account.")
            else:
                self.print_result("Root Account MFA", "FAIL", "Root account does NOT have MFA enabled!")
        except Exception as e:
            print(f"Error checking root MFA: {e}")

    # 5. Logging Enabled (CloudTrail)
    def check_cloudtrail_logging(self):
        trail_client = self.session.client('cloudtrail')
        try:
            trails = trail_client.describe_trails().get('trailList', [])
            active_trail = False
            for trail in trails:
                status = trail_client.get_trail_status(Name=trail['TrailARN'])
                if status.get('IsLogging', False):
                    active_trail = True
                    self.print_result(f"CloudTrail Active: {trail['Name']}", "PASS", "Trail is actively logging events.")
            if not active_trail:
                self.print_result("CloudTrail Logging Check", "FAIL", "No active CloudTrails found in this region.")
        except Exception as e:
            print(f"Error checking CloudTrail: {e}")

    # 6. IAM Access Key Rotation (90 Days)
    def check_key_rotation(self):
        iam = self.session.client('iam')
        from datetime import datetime, timezone, timedelta
        try:
            users = iam.list_users().get('Users', [])
            for user in users:
                username = user['UserName']
                keys = iam.list_access_keys(UserName=username).get('AccessKeyMetadata', [])
                for key in keys:
                    if key['Status'] == 'Active':
                        age = datetime.now(timezone.utc) - key['CreateDate']
                        if age > timedelta(days=90):
                            self.print_result(f"IAM Key Age: {username}", "FAIL", f"Active key ({key['AccessKeyId']}) is {age.days} days old (Threshold: 90).")
                        else:
                            self.print_result(f"IAM Key Age: {username}", "PASS", f"Key is {age.days} days old.")
        except Exception as e:
            print(f"Error checking Key Rotation: {e}")

    # 7. Public Snapshots (EBS)
    def check_public_snapshots(self):
        ec2 = self.session.client('ec2')
        try:
            # Filters snapshots owned by the account itself to avoid searching public ones
            snapshots = ec2.describe_snapshots(OwnerIds=[self.account_id]).get('Snapshots', [])
            public_snaps = 0
            for snap in snapshots:
                snap_id = snap['SnapshotId']
                attrs = ec2.describe_snapshot_attribute(Attribute='createVolumePermission', SnapshotId=snap_id)
                for perm in attrs.get('CreateVolumePermissions', []):
                    if perm.get('Group') == 'all':
                        self.print_result(f"EBS Snapshot Privacy: {snap_id}", "FAIL", "Snapshot is marked as PUBLIC.")
                        public_snaps += 1
            if public_snaps == 0:
                self.print_result("EBS Snapshot Check", "PASS", "No public EBS snapshots found.")
        except Exception as e:
            print(f"Error checking Snapshots: {e}")

    # 8. Overprivileged Roles (AdminAccess check)
    def check_overprivileged_roles(self):
        iam = self.session.client('iam')
        try:
            roles = iam.list_roles().get('Roles', [])
            for role in roles:
                role_name = role['RoleName']
                # Skip AWS managed service roles to reduce noise
                if "/aws-service-role/" in role['Path']:
                    continue
                
                attached_policies = iam.list_attached_role_policies(RoleName=role_name).get('AttachedPolicies', [])
                for policy in attached_policies:
                    if policy['PolicyArn'] == 'arn:aws:iam::aws:policy/AdministratorAccess':
                        self.print_result(f"Privileged Role: {role_name}", "WARNING", "Role has full 'AdministratorAccess' attached.")
        except Exception as e:
            print(f"Error checking Roles: {e}")

    def run_all(self):
        self.check_root_mfa()
        self.check_public_s3()
        self.check_open_security_groups()
        self.check_unencrypted_ebs()
        self.check_cloudtrail_logging()
        self.check_key_rotation()
        self.check_public_snapshots()
        self.check_overprivileged_roles()

if __name__ == "__main__":
    scanner = AWSPostureScanner()
    scanner.run_all()