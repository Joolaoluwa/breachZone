resource "aws_cloudwatch_event_target" "config_dispatcher_target" {


  rule = aws_cloudwatch_event_rule.config_remediation_rule.name


  target_id = "ConfigDispatcher"


  arn = aws_lambda_function.lambda["config_dispatcher"].arn

}



resource "aws_lambda_permission" "allow_eventbridge_dispatcher" {


  statement_id = "AllowExecutionFromEventBridge"


  action = "lambda:InvokeFunction"


  function_name = aws_lambda_function.lambda["config_dispatcher"].function_name


  principal = "events.amazonaws.com"


  source_arn = aws_cloudwatch_event_rule.config_remediation_rule.arn

}