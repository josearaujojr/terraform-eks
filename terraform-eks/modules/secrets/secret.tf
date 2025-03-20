resource "aws_iam_policy" "policy_secret" {
  name        = "${var.project_name}-secret-policy"
  description = "Policy to allow reading API tokens from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "role_secret" {
  name = "${var.project_name}-secret-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${var.aws_account_id}:oidc-provider/${var.oidc_issuer_url}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${var.oidc_issuer_url}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy_secret" {
  role       = aws_iam_role.role_secret.name
  policy_arn = aws_iam_policy.policy_secret.arn
}
