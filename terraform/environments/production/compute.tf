locals {
  control_plane = one([for name, n in var.nodes : name if n.role == "control_plane"])
  workers       = sort([for name, n in var.nodes : name if n.role == "worker"])
}

# La clé doit exister dans le projet : une clé créée hors projet n'est pas
# proposée aux VM de smb-g3.
resource "cloudstack_ssh_keypair" "admin" {
  name       = var.ssh_keypair_name
  public_key = var.ssh_public_key
  project    = var.project
}

resource "cloudstack_instance" "node" {
  for_each = var.nodes

  name             = each.key
  display_name     = each.key
  service_offering = var.service_offering
  template         = var.template
  zone             = var.zone
  project          = var.project

  network_id = cloudstack_network.asgard.id
  ip_address = each.value.ip
  keypair    = cloudstack_ssh_keypair.admin.name

  root_disk_size = each.value.root_disk_gb

  # Offre libre : vCPU et RAM fournis à la création.
  details = merge(
    {
      cpuNumber = tostring(each.value.cpu)
      memory    = tostring(each.value.memory_mb)
    },
    var.cpu_speed_mhz == null ? {} : { cpuSpeed = tostring(var.cpu_speed_mhz) },
  )

  # Sans expunge, une VM détruite garde son IP fixe jusqu'à la purge et
  # bloque le apply suivant (cycle destroy puis apply).
  expunge = true

  tags = {
    role = each.value.role
  }
}
