# IAM Role
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3-access-policy"
  description = "Allow EC2 to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",         # Bucket
          "arn:aws:s3:::${var.s3_bucket_name}/*"        # Objects in the bucket
        ]
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "s3_attach_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile_for_script" {
  name = "ec2-instance-profile-for-script"
  role = aws_iam_role.ec2_s3_role.name
}
