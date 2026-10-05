terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "gcs" {
    bucket = "team1-tfstate-920afb25"
    prefix = "terraform/bootstrap-state"
  }
}

provider "google" {
  project = var.project_id
}

data "google_project" "project" {}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "terraform_state" {
  name     = "team${var.team_id}-tfstate-${random_id.bucket_suffix.hex}"
  location = "EU"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "team${var.team_id}-github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "team${var.team_id}-github-provider"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

resource "google_service_account" "cicd" {
  account_id   = "team${var.team_id}-cicd"
  display_name = "CI/CD Pipeline Service Account"
}

# Least privilege: bara de roller Terraform-resurserna i root-modulen kräver
locals {
  cicd_project_roles = toset([
    "roles/compute.instanceAdmin.v1", # VM:ar, resource policy (schema)
    "roles/compute.networkAdmin",     # routes, router, NAT, adresser, subnät
    "roles/compute.securityAdmin",    # brandväggsregler
  ])
}

resource "google_project_iam_member" "cicd_roles" {
  for_each = local.cicd_project_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cicd.email}"
}

# State-filen: bara objekt i den egna bucketen, inte hela projektets storage
resource "google_storage_bucket_iam_member" "cicd_state" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_service_account_iam_member" "cicd_workload_identity" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# resource "google_service_account_key" "cicd" {
#  service_account_id = google_service_account.cicd.name
# }

# VM-tjänstekontot får skriva loggar till Cloud Logging (spårbarhet för blue team)
resource "google_project_iam_member" "vm_log_writer_1" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:team1-jumphost@itsx25-lab.iam.gserviceaccount.com"
}
