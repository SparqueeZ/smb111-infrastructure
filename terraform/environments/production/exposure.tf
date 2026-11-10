# Exposition par redirection de port, pas par NAT statique : une IP publique
# n'ouvre que les ports listés. Le filtrage par source (VPN, réseau de
# l'école) est porté par l'ACL du tier (Heimdall, lot 5).

# --- IP d'administration ----------------------------------------------------

resource "cloudstack_ipaddress" "admin" {
  vpc_id  = cloudstack_vpc.asgard.id
  zone    = var.zone
  project = var.project

  tags = {
    usage = "administration"
  }
}

resource "cloudstack_port_forward" "admin" {
  ip_address_id = cloudstack_ipaddress.admin.id
  project       = var.project

  # SSH vers Odin, qui sert de rebond vers les workers.
  forward {
    protocol           = "tcp"
    public_port        = 22
    private_port       = 22
    virtual_machine_id = cloudstack_instance.node[local.control_plane].id
  }

  # API Kubernetes.
  forward {
    protocol           = "tcp"
    public_port        = 6443
    private_port       = 6443
    virtual_machine_id = cloudstack_instance.node[local.control_plane].id
  }

  # DNS interne asgard.internal (dnsmasq sur Odin).
  forward {
    protocol           = "udp"
    public_port        = 53
    private_port       = 53
    virtual_machine_id = cloudstack_instance.node[local.control_plane].id
  }
}

# --- IP applicative ---------------------------------------------------------

resource "cloudstack_ipaddress" "app" {
  count = length(local.workers) > 0 ? 1 : 0

  vpc_id  = cloudstack_vpc.asgard.id
  zone    = var.zone
  project = var.project

  tags = {
    usage = "application"
  }
}

locals {
  app_ports = {
    http  = 80
    https = 443
  }
  app_lb_enabled = var.app_exposure == "loadbalancer" && length(local.workers) > 0
  app_pf_enabled = var.app_exposure == "port_forward" && length(local.workers) > 0
}

# Mode nominal : répartition vers Traefik (ports hôtes) sur tous les workers.
resource "cloudstack_loadbalancer_rule" "app" {
  for_each = local.app_lb_enabled ? local.app_ports : {}

  name          = "emarge-${each.key}"
  description   = "Traefik ${each.key} sur les workers"
  ip_address_id = cloudstack_ipaddress.app[0].id
  network_id    = cloudstack_network.asgard.id
  algorithm     = "roundrobin"
  protocol      = "tcp"
  public_port   = each.value
  private_port  = each.value
  member_ids    = [for w in local.workers : cloudstack_instance.node[w].id]
  project       = var.project
}

# Repli : redirection vers un seul worker.
resource "cloudstack_port_forward" "app" {
  count = local.app_pf_enabled ? 1 : 0

  ip_address_id = cloudstack_ipaddress.app[0].id
  project       = var.project

  dynamic "forward" {
    for_each = local.app_ports
    content {
      protocol           = "tcp"
      public_port        = forward.value
      private_port       = forward.value
      virtual_machine_id = cloudstack_instance.node[var.app_port_forward_target].id
    }
  }
}
