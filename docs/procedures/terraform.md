# Procédure Terraform

Projet SMB111 — Émarge · environnement `terraform/environments/production` · projet CloudStack `smb-g3`

Terraform décrit le VPC, le tier Asgard, la clé SSH, les trois VM, les deux IP publiques et leurs redirections. Les valeurs viennent de [architecture-cible.md](../architecture/architecture-cible.md).

## 1. Prérequis

- VPN NetBird connecté, racine ESNA installée dans le magasin Windows (lot 1).
- Terraform 1.9 ou plus récent (`terraform version`).
- Clés d'API CloudStack générées depuis le menu du compte.

## 2. Authentification

Les clés d'API contournent la 2FA. Elles ne vont ni dans Git, ni dans un fichier du dépôt, ni dans `terraform.tfvars`. On les définit dans la session PowerShell, qui les oublie à sa fermeture :

```powershell
$env:CLOUDSTACK_API_URL    = 'https://10.1.51.2:8443/client/api'
$env:CLOUDSTACK_API_KEY    = Read-Host 'Clé d''API'
$env:CLOUDSTACK_SECRET_KEY = Read-Host 'Clé secrète'
```

Le provider `cloudstack/cloudstack` est épinglé en 0.6.0 dans `versions.tf`. La 0.7.0 est écartée : elle ne retrouve pas une VM de projet lors de la création d'une redirection de port avec un compte non administrateur. Le fichier `.terraform.lock.hcl` est versionné : il fige les empreintes du provider pour Windows et Linux.

## 3. Valeurs propres au lab

Les valeurs relevées dans le lab sont les valeurs par défaut de `variables.tf` : template `Ubuntu 24.04 LTS`, offre `lab-libre (1-16 vCPU, 1-64 Go, local)` (le nom complet est exigé), offre réseau `DefaultIsolatedNetworkOfferingForVpcNetworks`, ACL `default_allow`. Sans autre réglage, Terraform crée les trois nœuds.

Pour surcharger une valeur (par exemple ne créer qu'Odin), copier l'exemple :

```powershell
cd terraform\environments\production
Copy-Item terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` est ignoré par Git.

## 4. État Terraform

L'état est local (`terraform.tfstate`). Il contient les identifiants de toutes les ressources : il est ignoré par Git et ne doit jamais être commité.

Règles :

1. **Un seul opérateur à la fois.** L'état n'est pas partagé et n'a pas de verrou distant. Avant un `plan` ou un `apply`, l'annoncer à l'équipe. Le poste de référence est celui qui détient l'état.
2. **Sauvegarde chiffrée après chaque `apply`**, hors dépôt :

   ```powershell
   .\scripts\backup-tfstate.ps1
   ```

   Le script chiffre l'état avec GnuPG (AES-256, phrase de passe saisie à la demande) dans `%USERPROFILE%\smb111-backups\tfstate` et garde les 20 dernières sauvegardes. La phrase de passe est connue de l'équipe et conservée dans son gestionnaire de mots de passe.
3. **Contrôle avant chaque commit** : `git status` ne doit montrer aucun fichier `tfstate`, `tfvars` ou `tfplan`.

Restauration ou passage de l'état à un autre opérateur :

```powershell
gpg --decrypt --output terraform\environments\production\terraform.tfstate <sauvegarde>.tfstate.gpg
terraform plan   # doit afficher « No changes »
```

## 5. Première mise en place

```powershell
terraform init
terraform plan
```

Le VPC est géré par Terraform comme le reste. Historique : celui du lot 1 avait été créé à la main, puis importé (`terraform import cloudstack_vpc.asgard smb-g3/<ID du VPC>`, l'ID étant préfixé par le projet). Cette commande ne sert plus que si un VPC est de nouveau créé hors Terraform.

Création par étapes :

| Étape | Contenu de `nodes` dans `terraform.tfvars` | Résultat |
|---|---|---|
| 1 | Odin seul | Tier, clé SSH, Odin, IP d'administration, redirections 22, 6443, 53 |
| 2 | Bloc `nodes` retiré de `terraform.tfvars` (valeur par défaut : trois nœuds) | Thor, Tyr, IP applicative, 80 et 443 |

À chaque étape :

```powershell
terraform plan -out tfplan
terraform apply tfplan
.\scripts\backup-tfstate.ps1
terraform output
```

## 6. Exposition de l'IP applicative

La variable `app_exposure` choisit le mode :

- `loadbalancer` (par défaut) : deux règles de load balancer CloudStack, 80 et 443, vers Thor et Tyr ;
- `port_forward` : redirection de 80 et 443 vers un seul worker (`app_port_forward_target`). C'est le repli si le VPC n'offre pas de load balancer public. L'écart est alors noté dans [socle-cloudstack.md](../architecture/socle-cloudstack.md).

## 7. Sorties

`terraform output` publie `admin_ip`, `app_ip`, `source_nat_ip` et `node_private_ips`. L'inventaire Ansible reprend ces valeurs. Les IP publiques peuvent changer après un `destroy` : relire les sorties, ne pas les recopier de mémoire.

## 8. Cycle destroy puis apply

Ce cycle prouve que l'infrastructure se reconstruit sans intervention manuelle.

```powershell
.\scripts\backup-tfstate.ps1
terraform destroy
terraform apply
terraform output
```

- `terraform destroy` supprime aussi le VPC. Le `apply` suivant le recrée avec un nouvel ID : aucun import n'est nécessaire.
- Cycle réalisé le 10/11/2026 : 11 ressources recréées en 1 min 10 s environ, plan « No changes » ensuite.
- Les clés d'hôte SSH des VM changent : `ssh-keygen -R <adresse>` avant de se reconnecter.
- Les VM sont purgées à la destruction (`expunge = true`). Sans cela, leurs IP fixes resteraient réservées et bloqueraient le `apply`.
- Les IP publiques peuvent changer (elles sont restées identiques le 10/11/2026) : mettre à jour l'inventaire Ansible, la règle NRPT des postes et les `certSANs` de l'API.
