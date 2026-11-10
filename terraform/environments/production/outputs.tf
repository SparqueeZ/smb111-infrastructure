# Ces sorties alimentent l'inventaire Ansible (lot 3). Les IP publiques
# peuvent changer après un destroy : toujours les relire ici.

output "admin_ip" {
  description = "IP d'administration : 22/tcp, 6443/tcp et 53/udp vers Odin."
  value       = cloudstack_ipaddress.admin.ip_address
}

output "app_ip" {
  description = "IP applicative : 80/tcp et 443/tcp vers les workers."
  value       = one(cloudstack_ipaddress.app[*].ip_address)
}

output "source_nat_ip" {
  description = "IP de sortie Internet des VM (Source NAT du VPC)."
  value       = cloudstack_vpc.asgard.source_nat_ip
}

output "node_private_ips" {
  description = "IP privées des nœuds, par nom d'hôte."
  value       = { for name, vm in cloudstack_instance.node : name => vm.ip_address }
}

output "control_plane" {
  description = "Nom d'hôte du nœud de contrôle."
  value       = local.control_plane
}

output "workers" {
  description = "Noms d'hôte des workers."
  value       = local.workers
}

output "app_exposure" {
  description = "Mode d'exposition effectif de l'IP applicative."
  value       = var.app_exposure
}

output "ssh_odin" {
  description = "Commande SSH vers Odin."
  value       = "ssh ubuntu@${cloudstack_ipaddress.admin.ip_address}"
}
