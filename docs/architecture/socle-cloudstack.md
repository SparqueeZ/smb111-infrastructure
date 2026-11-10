# Socle CloudStack : relevé et vérifications

Projet SMB111 — Émarge · projet CloudStack `smb-g3` · zone `Lab-ESNA`

Ce document consigne ce qui a été mesuré sur la plateforme. Chaque hypothèse de [architecture-cible.md](architecture-cible.md) §8 y passe à « validée » ou « invalidée ».

## 1. Relevé de la plateforme (API, 10/11/2026)

| Élément | Valeur relevée |
|---|---|
| Version de CloudStack | 4.22.1.1 |
| Hyperviseur | KVM |
| Zone | `Lab-ESNA`, réseau avancé, stockage local activé, sans groupes de sécurité |
| Template | `Ubuntu 24.04 LTS` (public, image cloud officielle `release-20261017`, QCOW2, taille virtuelle 3,5 Go, clé SSH et mot de passe pris en charge) |
| Offre de calcul | `lab-libre` : offre libre, 1 à 16 vCPU, 1 à 64 Go, fréquence fixée à 2000 MHz, stockage local. vCPU et RAM passés en détails (`cpuNumber`, `memory`) |
| Offre de VPC | `Default VPC offering`. Lb : `InternalLbVm` et `VpcVirtualRouter` |
| Offre réseau du tier | `DefaultIsolatedNetworkOfferingForVpcNetworks`. Tous les services par `VpcVirtualRouter`, Lb compris |
| ACL `default_allow` | ID `327b07b9-ced3-11f1-bc2c-bc2411fa02b7` (ACL globale) |
| VPC `vpc-smb-g3` | ID `987d7024-2c8d-42d6-bd78-7b4400a20e50`, 10.35.0.0/16, état Enabled |
| IP Source NAT | 10.0.50.26 |

### Limites du projet `smb-g3`

| Ressource | Limite | Consommé avant le lot 2 | Besoin | Tient ? |
|---|---|---|---|---|
| VM | 8 | 0 | 3 | oui |
| vCPU | 24 | 0 | 10 | oui |
| RAM | 48 Go | 0 | 20 Go | oui |
| IP publiques | 3 | 1 (Source NAT) | 2 de plus | oui, sans marge |
| Stockage primaire | 500 Go | 0 | 130 Go | oui |
| Volumes | 20 | 0 | 3 | oui |
| Réseaux | 4 | 0 | 1 | oui |
| VPC | 4 | 1 | 1 | oui |

L'IP Source NAT compte dans la limite d'IP : le budget ne laisse aucune IP de réserve.

## 2. Hypothèses

| # | Hypothèse | État | Preuve |
|---|---|---|---|
| 1 | Un template Ubuntu 24.04 avec cloud-init existe | **validée** | `listTemplates` ; cloud-init 26.1, `DataSourceCloudStack`, état `done` sur Odin |
| 2 | Un load balancer public est possible sur l'IP applicative | **validée** | Règles `emarge-http` et `emarge-https` actives ; 6 requêtes sur 10.0.50.33:80 réparties 3 / 3 entre Thor et Tyr (serveur HTTP temporaire) |
| 3 | L'IP Source NAT compte dans la limite d'IP | **validée** | `listProjects` : 3 IP sur 3 après le lot 2 |
| 4 | Hairpin vers l'IP publique du VPC | **validée** pour l'IP d'administration | Depuis Odin, 10.0.50.31:22 répond |
| 5 | MTU 1500 sur le tier | **invalidée** : le MTU des interfaces est **1450** | `ip link` sur les trois nœuds. Le MTU des pods (VXLAN, 50 octets d'en-tête) passe donc à **1400**, pas 1450 |
| 6 | Le provider Terraform 0.7.0 est compatible | **invalidée** : authentification, TLS, import et plan passent, mais `cloudstack_port_forward` échoue (VM de projet introuvable avec un compte non administrateur). Provider épinglé en **0.6.0**, qui fonctionne | `terraform apply` du 10/11/2026 |
| 7 | Le template injecte la clé SSH du projet par cloud-init | **validée** : voir §4 | VM de diagnostic du 10/11/2026 |

## 3. Vérifications depuis Odin (10/11/2026)

Session ouverte par `ssh ubuntu@10.0.50.31` depuis WSL (clé `asgard-admin`).

| Vérification | Résultat | Conclusion |
|---|---|---|
| Système | Ubuntu 24.04.5 LTS, noyau 6.8.0-147, 2 vCPU, 3,9 Go | conforme |
| cloud-init | `done`, source `DataSourceCloudStack`, aucune erreur. Quatre avertissements « Unable to obtain a DHCP lease on ens3 » pendant le démarrage, sans conséquence (l'adresse est bien obtenue) | terminé |
| Disque racine | `/dev/vda1` 29 Go, 6 % utilisés ; la partition a été étendue aux 30 Go demandés | conforme |
| Adresse | `ens3` 10.35.10.10/24, passerelle 10.35.10.1 | conforme |
| MTU de l'interface | **1450** | à reporter dans la configuration du CNI |
| MTU du chemin | `ping -M do` : 1430 octets passent vers 1.1.1.1 | cohérent avec 1450 |
| Résolution DNS | serveurs 10.35.10.1 et 10.0.50.1, domaine `csc4cloud.internal` ; `registry.k8s.io` et `github.com` résolus | fonctionne |
| Sortie Internet | `apt update` : 38 Mo en 5 s (miroir `lab-esna.clouds.archive.ubuntu.com`) ; `https://registry.k8s.io/v2/` répond 401 (attendu sans authentification) ; IP de sortie vue d'Internet : 82.96.147.206 | fonctionne |
| Heure | UTC, NTP actif et synchronisé | fuseau à régler au lot 3 |
| Swap | aucun | prérequis Kubernetes déjà rempli |
| `sudo` | sans mot de passe pour `ubuntu` | utilisable par Ansible |
| Accès à l'API CloudStack | `https://10.1.51.2:8443` : **aucune réponse** depuis la VM | l'API n'est pas joignable depuis les VM : pas de pilotage de CloudStack depuis le cluster (ni CCM, ni CSI CloudStack) |
| Hairpin | 10.0.50.31:22 répond depuis Odin ; 10.0.50.26 (Source NAT) ne répond pas sur le port 22, aucune redirection n'y existe | hairpin fonctionnel sur une IP redirigée |

### Trois nœuds

| Nœud | vCPU | RAM | Disque | MTU | Accès |
|---|---|---|---|---|---|
| `odin-cp-01` 10.35.10.10 | 2 | 4 Go | 30 Go | 1450 | SSH direct sur l'IP d'administration |
| `thor-wk-01` 10.35.10.11 | 4 | 8 Go | 50 Go | 1450 | SSH par rebond (`ssh -J ubuntu@10.0.50.31 ubuntu@10.35.10.11`) |
| `tyr-wk-02` 10.35.10.12 | 4 | 8 Go | 50 Go | 1450 | SSH par rebond |

Ping entre les trois adresses privées : 0 % de perte dans tous les sens.

Consommation du projet après le lot 2 : 3 VM sur 8, 10 vCPU sur 24, 20 Go sur 48, **3 IP sur 3**, 130 Go sur 500.

## 4. Connexion SSH : diagnostic du 10/11/2026

Symptôme : `ssh ubuntu@10.0.50.31` répondait `Permission denied (publickey,password)`.

**Cause : la clé privée du poste WSL est protégée par une phrase de passe**, ajoutée après sa création. Les tests étaient lancés sans terminal interactif : `ssh` ne pouvait pas demander la phrase de passe et la clé n'était donc jamais présentée. La plateforme et le template n'y sont pour rien.

Preuves, relevées sur une VM de diagnostic créée par l'API puis supprimée :

| Vérification | Résultat |
|---|---|
| Mot de passe de 16 caractères renvoyé à la création | Accepté pour `ubuntu` (pas pour `root`) |
| cloud-init | 26.1, source `DataSourceCloudStack`, terminé sans erreur |
| Métadonnées du routeur (`http://10.35.10.1/latest/meta-data/public-keys`) | Contiennent la clé `asgard-admin` |
| `/home/ubuntu/.ssh/authorized_keys` | Contient exactement la clé publique du poste |
| `sudo` sans mot de passe pour `ubuntu` | Oui |
| `ssh-keygen -y -f ~/.ssh/id_ed25519` sur le poste | « incorrect passphrase » : clé chiffrée |

À retenir sur le template `Ubuntu 24.04 LTS` :

- compte `ubuntu` ; la clé SSH du projet est bien injectée ;
- l'authentification SSH par mot de passe est activée par cloud-init (`50-cloud-init.conf`), parce que le template est « password enabled ». À désactiver au durcissement SSH (lot 3) ;
- le mot de passe n'est posé qu'au premier démarrage. Un « Reset password » ultérieur dans l'interface n'a aucun effet dans la VM ;
- le provider Terraform ne restitue pas le mot de passe de création : seule la clé SSH permet d'entrer.

Usage de la clé avec phrase de passe : la charger une fois dans un agent, puis lancer `ssh` ou Ansible.

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Ports joignables selon le réseau du poste

Depuis le Wi-Fi élèves (10.0.40.0/23), seuls les ports 22, 80, 443, 3389 et 5900-5910 des IP publiques répondent. Constaté : 6443 et 2222 expirent. Depuis le VPN NetBird, tous les ports passent. L'API Kubernetes (6443) et le DNS interne (53/udp) exigent donc le VPN, même sur place.
