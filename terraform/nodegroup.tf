resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id
  ]
  # The node security group
  disk_size       = 20
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  # Optionally override the default node SG:
  # remote_access {
  #   ec2_ssh_key = "my-key"
  #   source_security_group_ids = [aws_security_group.eks_node_sg.id]
  # }
}
