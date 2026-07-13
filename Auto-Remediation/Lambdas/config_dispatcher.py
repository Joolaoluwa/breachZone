import json
from datetime import datetime

import boto3
from botocore.exceptions import ClientError


# AWS clients
s3 = boto3.client("s3")
ec2 = boto3.client("ec2")


def log_action(action, resource_id, status, details=None):

    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "action": action,
        "resource_id": resource_id,
        "status": status,
        "details": details
    }

    print(json.dumps(log_entry))


# -----------------------------
# S3 REMEDIATION
# -----------------------------

def remediate_s3(resource_id):

    bucket_name = resource_id

    try:

        s3.put_public_access_block(
            Bucket=bucket_name,

            PublicAccessBlockConfiguration={

                "BlockPublicAcls": True,

                "IgnorePublicAcls": True,

                "BlockPublicPolicy": True,

                "RestrictPublicBuckets": True
            }
        )


        log_action(
            "BLOCK_PUBLIC_S3_ACCESS",
            bucket_name,
            "SUCCESS"
        )


    except ClientError as e:

        log_action(
            "BLOCK_PUBLIC_S3_ACCESS",
            bucket_name,
            "FAILED",
            str(e)
        )

        raise



# -----------------------------
# SECURITY GROUP REMEDIATION
# -----------------------------

def remediate_security_group(resource_id):

    sg_id = resource_id


    try:

        ec2.revoke_security_group_ingress(

            GroupId=sg_id,

            IpPermissions=[

                {

                    "IpProtocol": "tcp",

                    "FromPort": 22,

                    "ToPort": 22,

                    "IpRanges":[

                        {

                            "CidrIp":"0.0.0.0/0"

                        }

                    ]

                }

            ]

        )


        log_action(

            "REMOVE_PUBLIC_SSH_ACCESS",

            sg_id,

            "SUCCESS"

        )


    except ClientError as e:


        log_action(

            "REMOVE_PUBLIC_SSH_ACCESS",

            sg_id,

            "FAILED",

            str(e)

        )

        raise



# -----------------------------
# FUTURE PLACEHOLDERS
# -----------------------------


def remediate_iam(resource_id):

    log_action(

        "IAM_REMEDIATION",

        resource_id,

        "NOT_IMPLEMENTED"

    )



def remediate_secrets(resource_id):

    log_action(

        "SECRET_ROTATION",

        resource_id,

        "NOT_IMPLEMENTED"

    )



def remediate_ec2(resource_id):

    log_action(

        "EC2_ISOLATION",

        resource_id,

        "NOT_IMPLEMENTED"

    )



# -----------------------------
# MAIN DISPATCHER
# -----------------------------


def lambda_handler(event, context):


    print("===== CONFIG EVENT RECEIVED =====")

    print(json.dumps(event))


    detail = event.get("detail", {})


    rule_name = detail.get(
        "configRuleName"
    )


    resource_id = detail.get(
        "resourceId"
    )


    compliance_type = detail.get(
        "newEvaluationResult",
        {}
    ).get(
        "complianceType"
    )


    print(
        f"Rule: {rule_name}"
    )

    print(
        f"Resource: {resource_id}"
    )

    print(
        f"Compliance: {compliance_type}"
    )


    # Only remediate failures

    if compliance_type != "NON_COMPLIANT":

        log_action(

            "SKIPPED_COMPLIANT_RESOURCE",

            resource_id,

            "SKIPPED"

        )


        return {

            "statusCode":200,

            "message":"No remediation required"

        }



    # -----------------------------
    # ROUTING LOGIC
    # -----------------------------


    if rule_name == "s3-bucket-public-read-prohibited":


        remediate_s3(resource_id)



    elif rule_name == "restricted-ssh":


        remediate_security_group(resource_id)



    elif rule_name == "iam-user-unused-credentials-check":


        remediate_iam(resource_id)



    elif rule_name == "secretsmanager-rotation-enabled-check":


        remediate_secrets(resource_id)



    else:


        log_action(

            "UNKNOWN_CONFIG_RULE",

            resource_id,

            "NO_HANDLER",

            rule_name

        )



    return {


        "statusCode":200,


        "body":json.dumps({

            "rule": rule_name,

            "resource": resource_id,

            "action":"processed"

        })

    }