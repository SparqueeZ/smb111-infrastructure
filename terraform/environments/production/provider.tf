# Authentification par variables d'environnement, jamais dans un fichier :
#   CLOUDSTACK_API_URL     https://10.1.51.2:8443/client/api
#   CLOUDSTACK_API_KEY     clé d'API du compte
#   CLOUDSTACK_SECRET_KEY  clé secrète du compte
# Le certificat du lab est signé par la racine ESNA, installée dans le
# magasin de confiance du poste (lot 1) : aucune option « insecure ».
provider "cloudstack" {}
