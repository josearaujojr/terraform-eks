data "aws_iam_policy_document" "eso" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:us-east-1:${var.aws_account_id}:secret:*"
    ]
  }
}

resource "aws_iam_policy" "eso_policy" {
  name   = "eso-secretsmanager-policy"
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_iam_role" "eso_role" {
  name = "eso-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${var.oidc_issuer_url}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${var.oidc_issuer_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eso_attach" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_policy.arn
}

resource "kubernetes_service_account" "eso_sa" {
  metadata {
    name      = "external-secrets"
    namespace = "external-secrets"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso_role.arn
    }
  }
}

resource "aws_iam_policy" "policy_secret" {
  name        = "${var.project_name}-secret-policy"
  description = "Policy to allow reading API tokens from Secrets Manager and accessing S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::img-app0001",
          "arn:aws:s3:::img-app0001/*"
        ]
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
