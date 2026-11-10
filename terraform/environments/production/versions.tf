terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    # Épinglé en 0.6.0 et non en 0.7.0 : la 0.7.0 recherche la VM cible d'une
    # redirection de port sans préciser le projet. Avec un compte non
    # administrateur, la VM d'un projet est alors introuvable (« No match
    # found ») et cloudstack_port_forward échoue. La 0.6.0 passe le projet.
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "0.6.0"
    }
  }
}
