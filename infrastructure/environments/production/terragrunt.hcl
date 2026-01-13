include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/gke-cluster"
}

inputs = {
  project_id = "dogwood-actor-484201-t8"
  region     = "asia-southeast1"
  env        = "prod"

  subnet_cidr   = "10.10.0.0/16"
  pods_cidr     = "10.11.0.0/16"
  services_cidr = "10.12.0.0/16"

  node_config = {
    machine_type = "n2d-standard-4"
    min_nodes    = 1
    max_nodes    = 3
    disk_size_gb = 40
    preemptible  = false
  }
  resource_labels = {
    env          = "production"
    project      = "assignment-interview"
    managed_by   = "terraform"
    cost_center  = "devops-team"
  }
}
