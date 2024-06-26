resource "github_repository_deploy_key" "this" {
  title      = "flux-cd/${var.cluster_name}"
  repository = var.github_repository
  key        = var.public_key_openssh
  read_only  = "false"
}

# Bootstrap flux
resource "flux_bootstrap_git" "this" {
  path = "clusters/${var.cluster_name}"

  depends_on = [
    github_repository_deploy_key.this,
    github_repository_file.config,
    github_repository_file.kustomization,
    github_repository_file.secrets,
  ]
}

# Custom profile management
locals {
  flux_platform_path = "clusters/${var.cluster_name}/platform"
  #flux_apps_path = "clusters/${var.cluster_name}/apps"
}

resource "github_repository_file" "kustomization" {
  repository          = var.github_repository
  branch              = var.github_branch
  commit_message      = "[Flux] Configure Kustomization for ${var.cluster_name}"
  overwrite_on_create = var.overwrite_files_on_create
  file                = "${local.flux_platform_path}/kustomization.yaml"
  content             = templatefile(
    "${path.module}/templates/kustomization.sample.yaml", 
    {
      profile_name = var.profile_name,
      environment_type = var.environment_type
    }
  )
}

resource "github_repository_file" "secrets" {
  repository          = var.github_repository
  branch              = var.github_branch
  commit_message      = "[Flux] Configure cluster secrets for ${var.cluster_name}"
  overwrite_on_create = var.overwrite_files_on_create
  file                = "${local.flux_platform_path}/cluster-secrets.sops.yaml"
  content             = templatefile(
    "${path.module}/templates/secrets.sample.yaml", 
    {
      cluster_name = var.cluster_name,
      data = [for key, val in var.cluster_secrets : "${key}: encrypted(${val})"]
    }
  )
}

resource "github_repository_file" "config" {
  repository          = var.github_repository
  branch              = var.github_branch
  commit_message      = "[Flux] Configuring cluster config for ${var.cluster_name}"
  overwrite_on_create = var.overwrite_files_on_create
  file                = "${local.flux_platform_path}/cluster-configs.yaml"
  content             = templatefile(
    "${path.module}/templates/configs.sample.yaml", 
    {
      cluster_name = var.cluster_name,
      data = [ for key, val in var.cluster_config : "${key}: ${val}"]
    }
  )
}