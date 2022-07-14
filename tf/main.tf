provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

# Enable required APIs

resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "file.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  project = var.project
  service = each.value
}

# First we need the network for Filestore to attach to

resource "google_compute_network" "network" {
  name                    = "mynetwork"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name    = "mynetwork-${var.region}"
  network = google_compute_network.network.id
  region  = var.region

  private_ip_google_access = true
  ip_cidr_range            = "10.0.0.0/20"
  purpose                  = "PRIVATE"

  # Only required for GKE Autopilot
  secondary_ip_range = [{
    range_name    = "pods"
    ip_cidr_range = "10.0.32.0/19"
    }, {
    range_name    = "services"
    ip_cidr_range = "10.0.16.0/20"
  }]
}

resource "google_compute_router" "router" {
  name    = "mynetwork-${var.region}"
  network = google_compute_network.network.id
  region  = var.region
}

resource "google_compute_router_nat" "router_nat" {
  name   = "mynetwork-${var.region}"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_from_iap_to_instances" {
  name    = "allow-ssh-ingress-from-iap"
  network = google_compute_network.network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # https://cloud.google.com/iap/docs/using-tcp-forwarding#before_you_begin
  # This is the netblock needed to forward to the instances
  source_ranges = ["35.235.240.0/20"]
}

# Create the filestore instance

resource "google_filestore_instance" "instance" {
  name     = "my-filestore"
  location = var.filestore_location
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "data"

    nfs_export_options {
      ip_ranges   = ["10.0.0.0/20", "10.8.0.0/28"]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network = google_compute_network.network.name
    modes   = ["MODE_IPV4"]
  }

  depends_on = [google_project_service.services]
}

# Create VPC access connector for Cloud Run

resource "google_vpc_access_connector" "connector" {
  name          = "my-vpc-con"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.network.name

  depends_on = [google_project_service.services]
}

# Create GKE Autopilot cluster

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}



resource "google_container_cluster" "primary" {
  name     = "my-cluster"
  project  = var.project
  location = var.region

  enable_autopilot = true

  network    = google_compute_network.network.id
  subnetwork = google_compute_subnetwork.subnetwork.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
    master_global_access_config {
      enabled = true
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      # We limit master access to our own IP only
      cidr_block   = "${chomp(data.http.myip.body)}/32"
      display_name = "My IP"
    }
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

data "google_project" "project" {
  project_id = var.project
}

resource "google_project_iam_member" "ar_access" {
  project = var.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
