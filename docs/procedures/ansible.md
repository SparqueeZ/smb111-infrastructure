# Procédure — Socle système avec Ansible (lot 3)

Ansible configure les trois nœuds créés par Terraform : système, durcissement, containerd et paquets Kubernetes. Il s'exécute depuis WSL (décision D-02).

## Prérequis sur le poste

1. Ubuntu 24.04 sous WSL, `ansible` installé par pipx. Dépôt cloné dans `~/smb111-infrastructure` (pas sous `/mnt/c`).
2. Le répertoire `ansible/` ne doit pas être accessible en écriture à tous : `chmod 755 ~/smb111-infrastructure/ansible`. Sinon Ansible ignore `ansible.cfg`.
3. La clé SSH est chargée dans l'agent :
   ```bash
   export SSH_AUTH_SOCK=~/.ssh/agent.sock
   ssh-add -l          # doit lister la clé ed25519
   ```
4. Le mot de passe du vault est dans `ansible/.vault_pass` (droits 600). Ce fichier est ignoré par Git. Il se transmet entre membres de l'équipe par un canal sûr.
5. Les IP publiques de `group_vars/all/main.yml` correspondent à `terraform output admin_ip app_ip`.

## Contenu

| Fichier | Rôle |
|---|---|
| `inventory/hosts` | Groupes `control_plane`, `workers`, `k8s` |
| `group_vars/all/main.yml` | IP publiques, réseau, fuseau, version de Kubernetes |
| `group_vars/all/vault.yml` | Secrets chiffrés (Ansible Vault) |
| `group_vars/workers.yml` | Rebond SSH par Odin (`ProxyJump`) |
| `host_vars/<nœud>.yml` | `ansible_host`, `node_ip` |
| `roles/common` | Nom d'hôte, `/etc/hosts`, paquets, fuseau, NTP, swap, modules, sysctl, SSH, unattended-upgrades |
| `roles/containerd` | containerd 2.x, `SystemdCgroup = true`, image pause, `/etc/crictl.yaml` |
| `roles/kubernetes` | Dépôt `pkgs.k8s.io`, kubeadm, kubelet, kubectl et crictl (`cri-tools`) en version exacte, `apt-mark hold` |
| `01_base.yml`, `02_containerd.yml`, `03_kubernetes.yml` | Un playbook par étape |
| `site.yml` | Enchaîne les trois |

## Exécution

```bash
cd ~/smb111-infrastructure/ansible
ansible-inventory --graph          # trois nœuds dans les bons groupes
ansible all -m ping                # pong x3 (Thor et Tyr via Odin)
ansible-playbook site.yml --check --diff   # aperçu
ansible-playbook site.yml
ansible-playbook site.yml          # second passage : changed=0 partout
```

Le premier passage met à jour les paquets (`apt upgrade`) et peut durer plusieurs minutes.

## Vérifications

```bash
ansible k8s -a 'getent hosts thor-wk-01 k8s-api.asgard.internal'
ansible k8s -a 'timedatectl show -p NTPSynchronized -p Timezone'
ansible k8s -a 'swapon --show'                       # vide
ansible k8s -a 'sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables'
ansible k8s -b -a 'sshd -T' | grep -E 'passwordauth|permitroot'
ansible k8s -b -a 'unattended-upgrade --dry-run'
ansible k8s -a 'systemctl is-active containerd'
ansible k8s -b -a 'crictl info' | grep -i systemdcgroup
ansible k8s -a 'kubeadm version -o short'
ansible k8s -b -a 'apt-mark showhold'                # cri-tools kubeadm kubectl kubelet
```

Depuis le poste, un accès par mot de passe doit être refusé :

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ubuntu@<IP admin>
# ubuntu@...: Permission denied (publickey).
```

## Qualité

```bash
yamllint .
ansible-lint            # profil production
```

La GitHub Action `.github/workflows/ansible-lint.yml` rejoue ces contrôles à chaque push qui touche `ansible/`.

## Points d'attention

- **Recréation des VM** : les clés d'hôte changent. Il faut faire `ssh-keygen -R <IP admin>`, puis `ssh-keygen -R 10.35.10.1x` pour les workers.
- **Redémarrage** : `unattended-upgrades` ne redémarre jamais les nœuds. Après une mise à jour du noyau, `/var/run/reboot-required` apparaît. Le redémarrage se fait à la main, un nœud à la fois (lot 9).
- **Version de Kubernetes** : `kubernetes_version` dans `group_vars/all/main.yml`. Les paquets sont figés. Changer la valeur ne suffit pas à monter de version : il faut suivre la procédure de montée de version (lot 9).
- **crictl** : depuis Kubernetes 1.31, kubeadm ne dépend plus de `cri-tools`. Le rôle `kubernetes` l'installe explicitement (`kubernetes_cri_tools_version`), sinon `crictl` est absent des nœuds.
- **cloud-init** : `/etc/cloud/cloud.cfg.d/99-asgard.cfg` l'empêche de réécrire le nom d'hôte et `/etc/hosts` au redémarrage.
