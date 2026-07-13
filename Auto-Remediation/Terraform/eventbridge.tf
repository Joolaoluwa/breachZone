resource "aws_cloudwatch_event_rule" "config_remediation_rule" {


  name = "vaultcloud-remediation-trigger"


  event_pattern = jsonencode({

    source = [
      "aws.config"
    ]


    "detail-type" = [
      "Config Rules Compliance Change"
    ]

  })

}