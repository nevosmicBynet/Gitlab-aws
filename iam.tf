
resource "aws_iam_policy" "gitlab_s3_policy" {
  name        = "gl-s3-policy"
  description = "IAM policy for GitLab EC2 instances to access S3 buckets"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        Resource = "arn:aws:s3:::gl-*/*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:ListBucketMultipartUploads"
        ],
        Resource = "arn:aws:s3:::gl-*"
      }
    ]
  })
}

resource "aws_iam_role" "gitlab_s3_role" {
  name               = "GitLabS3Access"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_s3_policy_attachment" {
  role       = aws_iam_role.gitlab_s3_role.name
  policy_arn = aws_iam_policy.gitlab_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "GitLabS3InstanceProfile"
  role = aws_iam_role.gitlab_s3_role.name
}
