provider "aws" {
  region  = "eu-west-2"
  version = "~> 1.41"
  alias   = "default"
}

provider "local" {
  version = "~> 1.0"
  alias   = "default"
}

provider "null" {
  version = "~> 1.0"
  alias   = "default"
}

provider "template" {
  version = "~> 1.0"
  alias   = "default"
}

provider "tls" {
  version = "~> 1.0"
  alias   = "default"
}

terraform {
  backend "s3" {
    bucket = "gds-re-run-sandbox-terraform-state"
    region = "eu-west-2"
    key    = "rafalp.re-run-sandbox.aws.ext.govsvc.uk/cluster.tfstate"
  }
}

data "aws_caller_identity" "current" {}

module "cluster" {
  source = "../../modules/gsp-cluster"

  providers = {
    aws      = "aws.default"
    local    = "local.default"
    null     = "null.default"
    template = "template.default"
    tls      = "tls.default"
  }

  # AWS
  cluster_name = "rafalp"
  zone_name    = "run-sandbox.aws.ext.govsvc.uk"
  zone_id      = "Z23SW7QP3LD4TS"

  # configuration
  ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDm1xKMnwydS4TNtmEhCei6O9Zvxn7wVgkfhe6/nCfie/Ba82x52AAsMWONpuv54Acb6fcSeBAYpv68+3a94eg5fGDj39NvN5NBiPzl/OjwhANfX+P+8ax2eqNz9nBWJPpSAbu1fagTOqLQMqcsKwljJWhM2fGmG7jQMF806BEssCDtVcmF8MRjckhEnhOdKaiqbWYFHQXVAzgzgEQnaKkAq0H4IllopIOba431WlG1TFySnzUWI5k3Ep7He96L3J6dnt2lh0NfoGp1Kb05UEe71nBMS0okC1Rk1zDm7upNonVvBmo4S+1Aw8W+PEu16EH8h8kgfH0gPIqM1y1tYwibm8f8YkMyATA7fIQfmDMujborDRwi3JUI2d0I+nQTfT4xUfZEmh/PvHjegxvZ/dlp+up8fKVAY0ZSawTPhUapuBZaFn3kUjZbT6qSynlSObo6CqhHgPbkWkbIboXEhhYjx/Pgkm0E+vTI3Aq4amr8RXCH9J6/OmnZcTkGRIbC2rvY6W4OeqsrgGE9peB811YT5qfKx7eUNHGryS8hw0nNbLq7cRrfeMca9ddfH4YtQE0tX/IdYgMs1x89+yO4Pj8FsuCjQp7DFlzWKZgGPc+gnoYZz4aNeK3jBrvWF3HAQrCFkL04CjJJvhcGApfNgh42RoADqJOEyqGTH++radeAeQ== rafalp.run-sandbox.aws.ext.govsvc.uk"

  admin_role_arns = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/admin"]
}

module "gsp-base-release" {
  source = "../../modules/github-flux"

  namespace  = "gsp-base"
  chart_git  = "https://github.com/alphagov/gsp-base.git"
  chart_ref  = "master"
  chart_path = "charts/base"
}

module "gsp-monitoring-release" {
  source = "../../modules/github-flux"

  namespace  = "monitoring-system"
  chart_git  = "https://github.com/alphagov/gsp-monitoring.git"
  chart_ref  = "master"
  chart_path = "monitoring"
}

module "gsp-canary" {
  source     = "../../modules/canary"
  cluster_id = "rafalp.run-sandbox.aws.ext.govsvc.uk"
}
