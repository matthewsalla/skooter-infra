bucket                     = "terraform"
key                        = "deployment-environment-dev/terraform.tfstate"
region                     = "us-east-1"

# your MinIO credentials
access_key                 = "terraform"
secret_key                 = "superSecret123"

# point at your MinIO endpoint
endpoints                  = { s3 = "http://192.168.1.222:9900" }
use_path_style             = true

# disable AWS-only checks/lookups
skip_region_validation     = true
skip_credentials_validation= true
skip_metadata_api_check    = true
skip_requesting_account_id = true
