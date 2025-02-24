resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    # The cluster security group (if you want to override the default)
    security_group_ids = [
      aws_security_group.eks_cluster_sg.id
    ]
    subnet_ids = [
      aws_subnet.public[0].id,
      aws_subnet.public[1].id
    ]
  }
}

output "eks_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
