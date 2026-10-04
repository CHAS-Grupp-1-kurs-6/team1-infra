# Resurser skapade med gcloud 2026-10-05, importeras till Terraform.

import {
  to = google_compute_router.team
  id = "projects/itsx25-lab/regions/europe-north2/routers/team1-router"
}

import {
  to = google_compute_router_nat.team
  id = "projects/itsx25-lab/regions/europe-north2/routers/team1-router/team1-nat"
}

import {
  to = google_compute_firewall.allow_iap_ssh
  id = "projects/itsx25-lab/global/firewalls/team1-allow-iap-ssh"
}

import {
  to = google_compute_firewall.allow_headscale_proxy
  id = "projects/itsx25-lab/global/firewalls/team1-allow-headscale-proxy"
}

# Cloud NAT: primary når internet utan att gå via jumphost
resource "google_compute_router" "team" {
  name    = "team${var.team_id}-router"
  region  = var.region
  network = data.google_compute_network.team_vpc.id
}

resource "google_compute_router_nat" "team" {
  name                               = "team${var.team_id}-nat"
  router                             = google_compute_router.team.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.team.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# SSH endast via Google IAP
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "team${var.team_id}-allow-iap-ssh"
  network = data.google_compute_network.team_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["jumphost", "primary"]
}

# Lärarens proxy till Headscale på jumphost
resource "google_compute_firewall" "allow_headscale_proxy" {
  name    = "team${var.team_id}-allow-headscale-proxy"
  network = data.google_compute_network.team_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["10.0.0.2/32"]
  target_tags   = ["jumphost"]
}
