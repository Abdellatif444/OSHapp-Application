2. Démarrez docker:

```bash
cd backend/infra
docker compose up -d --build backend
```
La commande précédente va créer toutes les images Docker  automatiquement pour le backend, à savoir les quatre images ci-dessous :
3. Accès services par défaut pour mon cas:
- Backend API: `http://localhost:8081`:2c1df7fd7b56e367bb6cd856c36836d5572d69804ba5bc2d6e1abd4bc28c4b82
- mogodb: `http://localhost:27017`:325bce247e9a7e69a7a2b422006e432c5022fbaa7e7f257c1f377e32e668af81
- postgresql:`http://localhost:5432/`:fed9fb91e5b0dac4364119f96445a474f8009d6ff6775fd08fcd43fe5a4c5af9
- MinIO Console: `http://localhost:9001`:6721c52bdd2028279ba904fcd3f03d84f7fa3fa7c0c17c9e17b9d6f8bbecd801

 # Pour voir les images 
 ```bash
  docker images
```

# Check Docker services
 ```bash
  docker ps
```
# Check backend status
```bash
  docker compose  logs -f   backend
```
 # Reset everything

 ```bash
  docker compose-f .\infra\docker-compose.yml down-v
```
  ```bash
   docker compose-f .\infra\docker-compose.yml up-d
```

## 4)Lancer l’application Flutter (frontend) sur un téléphone physique plutôt que sur un émulateur :
 ```bash
 flutter run -d IZ9PKVGQUGWKL5FQ
```
 pour trouver "IZ9PKVGQUGWKL5FQ"  il faut executer cette commande:
 ```bash
 adb devices
```
# Check flutter status
 ```bash
  flutter logs -d IZ9PKVGQUGWKL5FQ
```
## 4)installer image apk du notre application :
 ```bash
 flutter build apk --debug
```
#output:build\app\outputs\flutter-apk\app-debug.apk
