# Architecture cible et plan d'adressage

Projet SMB111 — Émarge · projet CloudStack `smb-g3` · version gelée du 10/11/2026

Ce document fixe les adresses, les noms et les points d'entrée de l'infrastructure. Terraform (lot 2), Ansible (lot 3) et la configuration kubeadm (lot 4) en reprennent les valeurs. Toute modification passe par une mise à jour de ce fichier, relue par l'équipe.

## 1. Vue d'ensemble

```
Poste (VPN NetBird 100.64.0.0/10)                 Lab CloudStack ESNA (zone Lab-ESNA)
        │                                                    │
        │        ┌──────────── VPC vpc-smb-g3 · 10.35.0.0/16 ───────────────┐
        │        │                                                          │
        ├─► IP d'administration ─┐                                          │
        │   22, 6443, 53/udp     │   Bifrost (routeur virtuel du VPC)       │
        │                        ├──► 10.35.10.1 · ACL Heimdall             │
        └─► IP applicative ──────┘           │                              │
            80, 443                          │                              │
                                 ┌─ tier Asgard · 10.35.10.0/24 ──────┐     │
                                 │  odin-cp-01   10.35.10.10          │     │
                                 │  thor-wk-01   10.35.10.11          │     │
                                 │  tyr-wk-02    10.35.10.12          │     │
                                 └────────────────────────────────────┘     │
        IP Source NAT (sortie Internet des VM) ◄─────────────────────────────┘
```

Trois VM, un seul tier, un cluster Kubernetes kubeadm : un nœud de contrôle (Odin) et deux workers (Thor, Tyr) qui portent l'application à deux réplicas.

## 2. Nœuds

| Nom d'hôte | Rôle | IP privée | vCPU | RAM | Offre |
|---|---|---|---|---|---|
| `odin-cp-01` | control plane, etcd, DNS interne (dnsmasq), rebond SSH | 10.35.10.10 | 2 | 4 Go | `lab-libre` |
| `thor-wk-01` | worker, Traefik | 10.35.10.11 | 4 | 8 Go | `lab-libre` |
| `tyr-wk-02` | worker, Traefik | 10.35.10.12 | 4 | 8 Go | `lab-libre` |
| **Total** | | | **10** | **20 Go** | |

L'offre `lab-libre` accepte de 1 à 16 vCPU et de 1 à 64 Go, sur stockage local. Le total tient dans les limites relevées pour `smb-g3`.

Système : Ubuntu 24.04, template public `Ubuntu 24.04 LTS` du lab. Disque racine : 30 Go pour Odin, 50 Go pour chaque worker (stockage local).

## 3. Plan d'adressage

### 3.1 Réseaux

| Réseau | CIDR | Usage |
|---|---|---|
| VPC `vpc-smb-g3` | 10.35.0.0/16 | Super-réseau, géré par Terraform (l'ID change à chaque recréation : `terraform state show cloudstack_vpc.asgard`) |
| Tier Asgard | 10.35.10.0/24 | Réseau des trois VM |
| Pods (Calico VXLAN) | 10.244.0.0/16 | `podSubnet` kubeadm, pool IP Calico |
| Services Kubernetes | 10.96.0.0/12 | `serviceSubnet` kubeadm (10.96.0.0 à 10.111.255.255) |

### 3.2 Adresses fixes du tier Asgard

| Adresse | Attribution |
|---|---|
| 10.35.10.1 | Passerelle, Bifrost (routeur virtuel du VPC) |
| 10.35.10.2 à .9 | Réservées (services CloudStack, évolutions) |
| 10.35.10.10 | `odin-cp-01` |
| 10.35.10.11 | `thor-wk-01` |
| 10.35.10.12 | `tyr-wk-02` |
| 10.35.10.13 à .19 | Réservées : nœuds supplémentaires, IP virtuelle de l'API (bonus kube-vip) |
| 10.35.10.20 et au-delà | Libres |

Les IP des VM sont fixées dans Terraform, pas laissées au DHCP.

### 3.3 Adresses Kubernetes notables

| Adresse | Attribution |
|---|---|
| 10.96.0.1 | Service `kubernetes` (API dans le cluster) |
| 10.96.0.10 | CoreDNS |

### 3.4 Réseaux externes à ne pas chevaucher

| Réseau | CIDR | Rôle |
|---|---|---|
| VPN NetBird | 100.64.0.0/10 | Accès des postes de l'équipe et du jury |
| Réseau de l'école | 10.0.40.0/23 | Accès en soutenance |
| Lab CloudStack | 10.1.51.2 (interface) | Console et API CloudStack |

### 3.5 Contrôle des chevauchements

Les plages des tableaux 3.1 et 3.4 ont été comparées deux à deux (bornes de début et de fin) : **aucun chevauchement**. En particulier, le réseau des services (10.96.0.0/12) s'arrête à 10.111.255.255. Il ne touche ni le VPC (10.35.x) ni les pods (10.244.x).

## 4. Adresses publiques (budget IP)

Trois adresses publiques, dont deux acquises explicitement :

| IP | Origine | Ports exposés | Cible | Accès autorisé |
|---|---|---|---|---|
| Source NAT | Attribuée d'office au VPC | aucun | sortie Internet des VM | |
| IP d'administration | Acquise (Terraform) | 22/tcp | Odin | VPN, réseau école |
| | | 6443/tcp | Odin (API Kubernetes) | VPN uniquement |
| | | 53/udp | Odin (dnsmasq) | VPN uniquement |
| IP applicative | Acquise (Terraform) | 80/tcp, 443/tcp | Thor et Tyr (Traefik, ports hôtes) | VPN, réseau école |

- L'exposition passe par des redirections de port, pas par du NAT statique. Ainsi, une IP n'ouvre que les ports listés.
- Thor et Tyr sont joints par rebond SSH à travers Odin (`ProxyJump`). Ils n'ont pas de port SSH public.
- Les IP publiques ne sont pas figées : elles peuvent changer après un `terraform destroy`. Terraform les publie en sortie, et l'inventaire Ansible les reprend.
- L'IP Source NAT compte dans la limite d'IP du projet (3) : les deux IP acquises consomment tout le budget.

## 5. Noms et DNS

Domaine interne : `asgard.internal`. Il est servi par dnsmasq sur Odin, sauf si l'administrateur du lab fournit une zone (décision au lot 5). Le domaine réseau du VPC dans CloudStack reste `csc4cloud.internal`. Les deux sont distincts.

| Nom | Résout vers | Usage |
|---|---|---|
| `odin-cp-01`, `thor-wk-01`, `tyr-wk-02` | 10.35.10.10 / .11 / .12 | `/etc/hosts` des nœuds |
| `k8s-api.asgard.internal` | 10.35.10.10 dans le VPC, IP d'administration depuis le poste | `controlPlaneEndpoint` kubeadm (port 6443) |
| `emarge.asgard.internal` | IP applicative | Application Émarge |
| `auth.asgard.internal` | IP applicative | Keycloak (émetteur OIDC) |
| `grafana.asgard.internal` | IP applicative | Supervision |

- Les certificats de l'API ajoutent l'IP d'administration aux `certSANs`.
- Les certificats HTTPS sont émis par la PKI interne (`asgard-ca`, cert-manager).
- Sous Windows, les postes résolvent `.asgard.internal` par une règle NRPT pointant sur l'IP d'administration.

## 6. Composants Kubernetes

| Composant | Choix | Namespace |
|---|---|---|
| Installation | kubeadm, runtime containerd | |
| CNI | Calico, encapsulation VXLAN, BGP désactivé : le routeur du VPC ne connaît pas le réseau des pods | `calico-system` |
| Entrée HTTP/HTTPS | Traefik en DaemonSet sur les workers, ports hôtes 80 et 443 | `traefik` |
| Certificats | cert-manager, ClusterIssuer `asgard-ca` | `cert-manager` |
| Base de données | PostgreSQL en StatefulSet unique, volume local-path | `data` |
| Identités | Keycloak, realm `asgard`, OIDC pour Kubernetes, Grafana et Émarge | `identity` |
| Application | Émarge, API et web à deux réplicas, anti-affinité Thor / Tyr | `emarge` |
| Supervision | kube-prometheus-stack, Loki | `monitoring` |

## 7. Nomenclature

| Nom | Désigne |
|---|---|
| Asgard | Le tier et le domaine interne |
| Bifrost | Le routeur virtuel du VPC (passerelle 10.35.10.1) |
| Heimdall | L'ACL réseau du tier, qui remplacera `default_allow` au lot 5 |
| Odin, Thor, Tyr | Les trois nœuds |
| Mimir | Le volume de sauvegarde (pg_dump, instantanés etcd) |

### ACL Heimdall (cible, lot 5)

| Sens | Ports | Source ou destination |
|---|---|---|
| Entrée | 22, 80, 443/tcp | 100.64.0.0/10, 10.0.40.0/23 |
| Entrée | 6443/tcp, 53/udp | 100.64.0.0/10 |
| Sortie | limitée au nécessaire (apt, registres d'images, NTP, DNS) | à préciser dans la matrice des flux (lot 10) |

Jusqu'au cluster fonctionnel, l'ACL `default_allow` reste en place pour ne pas se bloquer.

## 8. Hypothèses et points ouverts

| # | Point | Effet | Tranché par |
|---|---|---|---|
| 1 | ~~Aucun template Ubuntu trouvé dans le lab~~ | **Levé le 10/11/2026** : template public `Ubuntu 24.04 LTS` (image cloud officielle, KVM, 3,5 Go) | Relevé par l'API (lot 2) |
| 2 | ~~Service Lb fourni par `InternalLbVm` seulement~~ | **Levé le 10/11/2026** : l'offre de VPC fournit Lb par `InternalLbVm` **et** `VpcVirtualRouter`, et l'offre de tier `DefaultIsolatedNetworkOfferingForVpcNetworks` par `VpcVirtualRouter`. Load balancer public **confirmé** : règles 80 et 443 vers Thor et Tyr, répartition vérifiée | Lot 2 |
| 3 | ~~L'IP Source NAT compte-t-elle dans la limite ?~~ | **Tranché le 10/11/2026** : oui. Limite de 3 IP, 1 consommée par la Source NAT (10.0.50.26). Il reste exactement les 2 IP du budget | Relevé par l'API (lot 2) |
| 4 | ~~Hairpin : une VM peut-elle joindre l'IP publique du VPC ?~~ | **Levé le 10/11/2026** : oui, Odin joint l'IP d'administration sur un port redirigé | Vérifications depuis Odin (lot 2) |
| 5 | ~~MTU 1500 sur le tier~~ | **Corrigé le 10/11/2026** : le MTU des interfaces est 1450. MTU des pods à **1400** (VXLAN) | Mesuré au lot 2, à confirmer au test de fumée réseau (lot 4) |
| 7 | L'API CloudStack n'est pas joignable depuis les VM | Pas d'intégration CloudStack dans le cluster ; tout passe par Terraform depuis le poste | Constat du lot 2 |
| 8 | Depuis le Wi-Fi élèves, seuls 22, 80, 443, 3389 et 5900-5910 sont joignables | L'API Kubernetes (6443) et le DNS interne (53/udp) exigent le VPN, y compris en soutenance | Constat du lot 2 |
| 6 | ~~Version de CloudStack et hyperviseur non communiqués~~ | **Levé le 10/11/2026** : CloudStack 4.22.1.1, hyperviseur KVM. Le provider Terraform 0.7.0 échoue sur les redirections de port dans un projet : provider épinglé en 0.6.0 | Relevé par l'API (lot 2) |

## 9. Validation

- [ ] Relu par l'équipe (noms et date) :
- [x] Aucun chevauchement de CIDR (§3.5)
