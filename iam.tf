resource "aws_iam_role" "this" {
  name               = "eMASE-app"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


data "aws_iam_policy" "ssm_access" {
  name = "AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.ssm_access.arn
}


resource "aws_iam_instance_profile" "this" {
  name = "eMASE-instance-profile"
  role = aws_iam_role.this.name
}
