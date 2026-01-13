locals {
  project_id = "dogwood-actor-484201-t8"
  region     = "asia-southeast1"
  bucket     = "pattarapongth-tf-state-2025"
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = local.bucket
    prefix  = "${path_relative_to_include()}/terraform.tfstate"
    project = local.project_id
    location = local.region
  }
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
EOF
}
