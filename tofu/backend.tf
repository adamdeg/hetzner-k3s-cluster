terraform {
  backend "s3" {
    bucket                      = "your-bucket-name"
    key                         = "hcloud/k3s/tofu.tfstate"
    endpoint                    = "your-bucket-endpoint"
    region                      = "your-bucket-region"
    
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}