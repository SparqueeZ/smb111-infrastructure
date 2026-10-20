
# SMB111 — Émarge

Projet CNAM SMB111 — 2026/2027

## Objectif

Concevoir, déployer et administrer une infrastructure
Cloud sécurisée basée sur Kubernetes et automatisée
avec Terraform et Ansible.

L'infrastructure hébergera Émarge, une application
d'émargement développée dans le cadre du projet.

## Technologies

- Cloud : Infomaniak Public Cloud / OpenStack
- Infrastructure as Code : Terraform
- Configuration : Ansible
- Orchestration : Kubernetes (kubeadm)
- Runtime : containerd
- Identités : Keycloak / OIDC
- Reverse proxy : Traefik
- Monitoring : Prometheus / Grafana / Loki
- Base de données : PostgreSQL

## Organisation

- infrastructure/ : provisioning et configuration
- kubernetes/ : manifests Kubernetes
- apps/ : code de l'application Émarge
- docs/ : architecture et documentation
- scripts/ : scripts utilitaires

## Sécurité

Aucun identifiant, mot de passe ou secret en clair
ne doit être stocké dans ce dépôt.

## Statut

Projet en cours — Phase d'initialisation.

## Échéance

Janvier 2027.
