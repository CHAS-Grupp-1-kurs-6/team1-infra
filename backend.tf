terraform {
  backend "gcs" {
    bucket = "team1-tfstate-920afb25"
    prefix = "terraform/state"
  }
}
