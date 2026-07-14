provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    ec2 = "http://localhost:4566"
    eks = "http://localhost:4566"
    ecr = "http://localhost:4566"
    iam = "http://localhost:4566"
  }
}

resource "aws_eks_cluster" "main" {
  name     = "devops-pro-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = ["subnet-12345"]
  }
}

resource "aws_ecr_repository" "repo" {
  name = "devops-pro-repo"
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

output "kubeconfig" {
  value = aws_eks_cluster.main.endpoint
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "devops-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
