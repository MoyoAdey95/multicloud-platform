# The workflow passes this to aws-actions/configure-aws-credentials. It is not
# a secret.
output "role_arn" {
  description = "ARN of the role the workflow assumes."
  value       = aws_iam_role.this.arn
}
