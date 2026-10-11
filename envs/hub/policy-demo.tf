# Deliberately breaks policy to show the plan workflow stopping it. Never merged.
resource "google_storage_bucket" "policy_demo" {
  name     = "moyo-platform-policy-demo"
  location = "EU"
}
