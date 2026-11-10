# Le VPC est entièrement géré par Terraform. Celui du lot 1, créé à la main,
# avait été importé ; le cycle destroy puis apply l'a recréé.
# (voir docs/procedures/terraform.md)
resource "cloudstack_vpc" "asgard" {
  name           = var.vpc_name
  display_text   = var.vpc_display_text
  cidr           = var.vpc_cidr
  vpc_offering   = var.vpc_offering
  network_domain = var.vpc_network_domain
  zone           = var.zone
  project        = var.project
}

# Tier Asgard : réseau unique des trois VM.
resource "cloudstack_network" "asgard" {
  name             = var.tier_name
  display_text     = "Tier Asgard"
  cidr             = var.tier_cidr
  gateway          = var.tier_gateway
  network_offering = var.tier_network_offering
  vpc_id           = cloudstack_vpc.asgard.id
  acl_id           = var.tier_acl_id
  zone             = var.zone
  project          = var.project
}
