terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52.1"
    }
  }
}

provider "openstack" {
  auth_url    = "http://192.168.0.10:5000"
  tenant_name = "admin"
  user_name   = "admin"
  password    = "JE6663lP1THXJqP8zVCWz3OQxqyXzu74b7Cd0Z7s"
  domain_name = "Default"
}
