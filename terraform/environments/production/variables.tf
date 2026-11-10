# Valeurs reprises de docs/architecture/architecture-cible.md.
# Aucune variable ne porte de secret : les clés d'API passent par
# l'environnement (voir provider.tf).

variable "project" {
  description = "Projet CloudStack qui porte toutes les ressources."
  type        = string
  default     = "smb-g3"
}

variable "zone" {
  description = "Zone CloudStack."
  type        = string
  default     = "Lab-ESNA"
}

# --- VPC (créé à la main au lot 1, importé dans l'état) ---------------------

variable "vpc_name" {
  description = "Nom du VPC."
  type        = string
  default     = "vpc-smb-g3"
}

variable "vpc_display_text" {
  description = "Description du VPC (valeur saisie à la création manuelle)."
  type        = string
  default     = "Réseau privé pour projet SMB111."
}

variable "vpc_cidr" {
  description = "Super-réseau du VPC."
  type        = string
  default     = "10.35.0.0/16"
}

variable "vpc_offering" {
  description = "Offre de VPC."
  type        = string
  default     = "Default VPC offering"
}

variable "vpc_network_domain" {
  description = "Domaine réseau du VPC dans CloudStack (distinct de asgard.internal)."
  type        = string
  default     = "csc4cloud.internal"
}

# --- Tier Asgard ------------------------------------------------------------

variable "tier_name" {
  description = "Nom du tier."
  type        = string
  default     = "asgard"
}

variable "tier_cidr" {
  description = "Réseau du tier Asgard."
  type        = string
  default     = "10.35.10.0/24"
}

variable "tier_gateway" {
  description = "Passerelle du tier (Bifrost, routeur virtuel du VPC)."
  type        = string
  default     = "10.35.10.1"
}

variable "tier_network_offering" {
  description = "Offre réseau du tier."
  type        = string
  default     = "DefaultIsolatedNetworkOfferingForVpcNetworks"
}

variable "tier_acl_id" {
  description = "ID de l'ACL réseau du tier. default_allow (ACL globale du lab) jusqu'au lot 5, puis Heimdall."
  type        = string
  default     = "327b07b9-ced3-11f1-bc2c-bc2411fa02b7"
}

# --- Machines virtuelles ----------------------------------------------------

variable "template" {
  description = "Nom ou ID du template Ubuntu 24.04 (image cloud officielle, cloud-init, 3,5 Go)."
  type        = string
  default     = "Ubuntu 24.04 LTS"
}

variable "service_offering" {
  description = "Nom complet ou ID de l'offre de calcul. lab-libre est une offre libre : vCPU et RAM sont passés en détails."
  type        = string
  default     = "lab-libre (1-16 vCPU, 1-64 Go, local)"
}

variable "cpu_speed_mhz" {
  description = "Fréquence CPU à passer à l'offre libre, si elle l'exige. null : paramètre omis."
  type        = number
  default     = null
}

variable "ssh_keypair_name" {
  description = "Nom de la paire de clés SSH dans le projet."
  type        = string
  default     = "asgard-admin"
}

variable "ssh_public_key" {
  description = "Clé publique SSH injectée dans les VM (clé ed25519 du poste de contrôle WSL)."
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHrjQ7G4ocam+83GmL7RcordZKrqiKqmL+RYja9ICBq4 leb@smb111-wsl"
}

variable "nodes" {
  description = "Nœuds du cluster. La clé est le nom d'hôte."
  type = map(object({
    role         = string # control_plane | worker
    ip           = string
    cpu          = number
    memory_mb    = number
    root_disk_gb = optional(number) # null : taille du template (3,5 Go)
  }))
  default = {
    "odin-cp-01" = { role = "control_plane", ip = "10.35.10.10", cpu = 2, memory_mb = 4096, root_disk_gb = 30 }
    "thor-wk-01" = { role = "worker", ip = "10.35.10.11", cpu = 4, memory_mb = 8192, root_disk_gb = 50 }
    "tyr-wk-02"  = { role = "worker", ip = "10.35.10.12", cpu = 4, memory_mb = 8192, root_disk_gb = 50 }
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : contains(["control_plane", "worker"], n.role)])
    error_message = "Le rôle d'un nœud vaut control_plane ou worker."
  }

  validation {
    condition     = length([for n in values(var.nodes) : n if n.role == "control_plane"]) == 1
    error_message = "Il faut exactement un nœud control_plane (cible des redirections d'administration)."
  }
}

# --- Exposition -------------------------------------------------------------

variable "app_exposure" {
  description = <<-EOT
    Mode d'exposition de 80/443 sur l'IP applicative :
    - loadbalancer : règle de load balancer CloudStack vers tous les workers ;
    - port_forward : redirection vers un seul worker (repli si le service Lb
      public n'est pas disponible dans le VPC, écart documenté).
  EOT
  type        = string
  default     = "loadbalancer"

  validation {
    condition     = contains(["loadbalancer", "port_forward"], var.app_exposure)
    error_message = "app_exposure vaut loadbalancer ou port_forward."
  }
}

variable "app_port_forward_target" {
  description = "Worker cible de 80/443 en mode port_forward."
  type        = string
  default     = "thor-wk-01"
}
