# Registre des décisions d'architecture

Projet SMB111 — Émarge. Chaque décision est datée, justifiée et reliée à la tâche qui l'a produite. Une décision remplacée n'est pas effacée : elle passe au statut « remplacée par D-xx ».

| # | Décision | Date | Statut |
|---|---|---|---|
| D-01 | Structure du projet Ansible : celle du cours | 10/11/2026 | adoptée |
| D-02 | Poste de contrôle Ansible : WSL2 Ubuntu 24.04 | 10/11/2026 | adoptée |
| D-03 | Kubernetes 1.37 (v1.37.2), runtime containerd 2.2 | 10/11/2026 | adoptée |

## D-01 — Structure du projet Ansible

**Décision.** On garde la structure du TP Ansible du cours : `ansible.cfg`, `inventory/hosts`, `group_vars/`, `host_vars/`, `files/`, `templates/` et les playbooks à la racine de `ansible/`. Les rôles sont autorisés dans `roles/`.

**Raisons.** Le correcteur retrouve une arborescence connue. Les rôles (`common`, `containerd`, `kubernetes`) évitent des playbooks monolithiques et se réutilisent d'un lot à l'autre.

**Conséquences.** `group_vars/all/` est un répertoire (`main.yml` en clair, `vault.yml` chiffré). Les playbooks sont numérotés (`01_base.yml`, `02_containerd.yml`, `03_kubernetes.yml`) et `site.yml` les enchaîne.

## D-02 — Poste de contrôle Ansible

**Décision.** Ansible tourne dans WSL2 (Ubuntu 24.04) sur le poste Windows. Terraform reste sous PowerShell.

**Raisons.** Ansible ne s'exécute pas nativement sous Windows. Terraform dispose d'un binaire Windows et y garde son état.

**Conséquences.**
- Le dépôt est cloné dans le système de fichiers Linux (`~/smb111-infrastructure`). Sous `/mnt/c`, les répertoires sont accessibles en écriture à tous et Ansible ignore `ansible.cfg`.
- La clé SSH est chargée dans un agent (`SSH_AUTH_SOCK=~/.ssh/agent.sock`) : elle est protégée par une phrase de passe.

## D-03 — Version de Kubernetes et du runtime

**Décision.** Kubernetes **1.37**, version exacte **1.37.2** (paquets `1.37.2-1.1` du dépôt `pkgs.k8s.io/core:/stable:/v1.37`), figés par `apt-mark hold`. Runtime : **containerd 2.2.1**, paquet Ubuntu de `noble-updates`, pilote de cgroup systemd.

Valeurs inscrites dans `ansible/group_vars/all/main.yml` (`kubernetes_version`) et `ansible/roles/containerd/defaults/main.yml`.

**Relevé du 10/11/2026.**

| Source | Constat |
|---|---|
| `dl.k8s.io/release/stable.txt` | v1.37.2, dernière version stable ; 1.38 n'est pas publiée |
| `dl.k8s.io/release/stable-1.36.txt` | v1.36.6 |
| Dépôt `pkgs.k8s.io` v1.37 | kubeadm, kubelet, kubectl 1.37.0 à 1.37.2 (`-1.1`) |
| Calico v3.33.0 (01/10/2026), page *System requirements* | testé avec Kubernetes 1.35, 1.36 et 1.37 |
| Ubuntu 24.04 `noble-updates` | containerd 2.2.1 |

**Raisons.**
- 1.37 est la dernière version mineure stable. Elle reste maintenue jusqu'à la fin du projet (janvier 2027) et au-delà. Une montée de version mineure pendant le projet n'est donc pas nécessaire.
- Le CNI retenu (Calico VXLAN, voir architecture-cible §6) est testé sur 1.37 depuis la v3.33. La 1.37 ne bloque donc pas le lot 4.
- containerd 2.x : la documentation Kubernetes (*Container Runtimes*) annonce qu'à partir de 1.38, les containerd 1.x ne fonctionneront plus avec le kubelet, faute de gérer l'appel CRI `RuntimeConfig`. Partir en 2.x évite de changer de runtime à la prochaine montée de version. Le paquet Ubuntu fournit containerd 2.2. Il suit les correctifs de sécurité d'Ubuntu, sans ajouter le dépôt Docker.
- La version exacte est figée et `unattended-upgrades` exclut les paquets Kubernetes. Les trois nœuds restent ainsi alignés. Une montée de version se fait par la procédure du lot 9.

**Alternative écartée.** 1.36.6 : plus éprouvée, mais sa fin de support arrive plus tôt. Elle n'apporte rien en compatibilité, puisque Calico 3.33 couvre les deux versions.

**À vérifier au lot 5.** La compatibilité des charts Helm (Traefik, cert-manager, kube-prometheus-stack, Keycloak) avec 1.37, au moment de leur déploiement.

**Conséquence pour le poste.** `kubectl` et `kubelogin` du poste suivent la même version mineure, à ±1 près.
