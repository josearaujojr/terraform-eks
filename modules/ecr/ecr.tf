resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"
  tags                 = var.tags

  provisioner "local-exec" {
    command = "sleep 30"
  }
}