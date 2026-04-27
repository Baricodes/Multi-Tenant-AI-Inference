# -----------------------------------------------------------------------------
# Repository Name Set
# -----------------------------------------------------------------------------

locals {
  ecr_repository_names = toset([
    "jabari/summarizer-service",
    "jabari/generator-service",
    "jabari/embedder-service",
  ])
}

# -----------------------------------------------------------------------------
# Service Image Repositories
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "service" {
  for_each = local.ecr_repository_names

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# -----------------------------------------------------------------------------
# Image Cleanup Policies
# -----------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = local.ecr_repository_names

  repository = aws_ecr_repository.service[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
