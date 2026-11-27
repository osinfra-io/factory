# Remote State Data Source
# https://opentofu.org/docs/language/state/remote

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket = "mock"
  }
  workspace = "mock"
}
