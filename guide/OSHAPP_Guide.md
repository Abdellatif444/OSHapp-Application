# OSHapp — Guide de passation et réutilisation du code

# OSHapp — Guide du Projet (Complet et Vérifié)

## Aperçu
- **Backend**: Spring Boot 3.5.4 (Java 17), Maven
- **Sécurité**: JWT stateless (profils `local`/`docker`) et mode Keycloak (profil `keycloak`)
- **BBDD**: PostgreSQL (JPA/Hibernate, DDL auto `update`)
- **Stockage**: MinIO via Docker 
- **Messagerie**: Gmail SMTP (Spring Mail)
- **Frontend**: Flutter Web (servi par Nginx en Docker)
- **Infra**: Docker Compose (Postgres, MongoDB, MinIO, Keycloak, Backend, Frontend)

Références vérifiées:
- `backend/pom.xml` (Spring Boot 3.5.4, Java 17)
- `backend/src/main/resources/application.yaml` (profil `local`)
- `backend/src/main/resources/application-docker.yml` (profil `docker`)
- `backend/infra/docker-compose.yml` (services & ports)
- `frontend/pubspec.yaml` (Flutter)

## Structure du dépôt
- `backend/`
  - API Spring Boot, configs, sécurité, seeds
  - `infra/docker-compose.yml`
  - `src/main/resources/application.yaml`, `application-docker.yml`
- `frontend/`
  - Application Flutter Web, `Dockerfile`, `nginx.conf`, `pubspec.yaml`
- `guide/`
  - Documentation existante (`OSHAPP_Guide.md`, `OSHAPP_Guide.docx`)

## Profils de sécurité et auth
- **Profil `local`**: authentification interne + JWT via `JwtTokenProvider`.
- **Profil `docker`**: idem `local`, exclusions OAuth2 RS (voir `application-docker.yml`).
- **Profil `keycloak`**: OAuth2 Resource Server + `JwtAuthConverter` (mappage des rôles Keycloak).

Endpoints Swagger ouverts: `/swagger-ui.html`, `/swagger-ui/**`, `/v3/api-docs/**`.
CORS autorisé (par défaut): `http://localhost:3001` et `*` (voir `SecurityConfig`).

## Rôles
- `ROLE_ADMIN`, `ROLE_RH`, `ROLE_NURSE`, `ROLE_DOCTOR`, `ROLE_EMPLOYEE`, `ROLE_HSE`.

## Entités clés (JPA)
- `User`, `Role`, `Employee`
- `Appointment`, `AppointmentComment`
- `Notification`, `AuditLog`, `Setting`, `WorkflowStep`
- `ActivationToken`, `PasswordResetToken`
- `Company`, `WorkAccident`
- `MedicalCertificate`, `SickLeaveCertificate`

## API — Contrôleurs et Endpoints
- `AuthController` (`/api/v1/auth`)
  - `POST /login`
  - `POST /google`
  - `POST /forgot-password`
  - `POST /reset-password`
- `AccountController` (`/api/v1/account`)
  - `POST /activate`
  - `POST /resend-activation`
- `AdminController` (`/api/v1/admin`)
  - `POST /users`, `GET /users`, `GET /users/{id}`, `PUT /users/{id}`, `DELETE /users/{id}`
  - `GET /dashboard`
  - `GET /statistics`
  - Rôles: `GET/POST/PUT/DELETE /roles`, managers: `PUT /employees/{id}/managers`
  - Profil employé par userId: `PUT /users/{id}/employee-profile`
- `EmployeeController` (`/api/v1/employees`)
  - `GET /` (liste)
  - `GET /for-medical-planning`
  - `GET /subordinates`
  - `GET /profile`, `GET /profile/me`, `GET /profile/status`, `PUT /profile`
  - `POST|PUT /create-complete`
  - `GET /stats`
  - `GET /medical-fitness/{employeeId}`
  - `GET /medical-fitness/history/{employeeId}`
- `AppointmentController` (`/api/v1/appointments`)
  - `GET /employee/{employeeId}`
  - `GET /` (tous)
  - `GET /history`
  - `POST /filter`
  - `GET /{id}`
  - `POST /Rendez-vous-spontanee`
  - `POST /{id}/propose-slot`
  - `POST /{id}/confirm`
  - `PUT /{id}/status?status=...`
  - `POST /{id}/cancel`
  - `POST /{id}/comments`
  - `DELETE /{id}`
  - `GET /my-appointments`
  - `POST /plan-medical-visit`
  - `DELETE /reset-all` (tests)
  - `POST /{id}/resend-notifications`
- `NotificationController` (`/api/v1/notifications`)
  - `GET /` (page), `GET /unread` (liste), `GET /count`
  - `PATCH /{id}/read`, `PATCH /read-all`
  - `DELETE /{id}`, `DELETE /reset-all`
- `HrController` (`/api/v1/hr`)
  - `GET /medical-certificates`
  - `GET /medical-certificates/uploads`
  - `GET /work-accidents`
  - `POST /mandatory-visits`
  - `POST /medical-certificates/upload` (multipart)
- `NurseCertificatesController` (`/api/v1/nurse`)
  - `GET /medical-certificates/uploads?employeeId=`

## Données de test (seed)
Création automatique si la base est vide (`DataInitializer`):
- `admin@oshapp.com / admin12345678` (ADMIN, activé)
- `abdelatifgourri11@gmail.com / Abdellatif12345678@` (DOCTOR)
- `gourriabde@gmail.com / Gourri12345678@` (NURSE)
- `avdjdcsb@gmail.com / Abcd12345678@` (RH)
- `salarie@oshapp.com / salarie123` (EMPLOYEE)
- `hse@oshapp.com / hse12345678` (HSE)
- `gourri.abdellatif@gmail.com / Abdellatif12345678@` (EMPLOYEE)

Note: seuls les comptes ADMIN sont activés par défaut; les autres nécessitent activation email.

## 1) Liens de livraison à compléter
- **Lien GitHub (version fédérée, code source complet)**: (https://github.com/Abdellatif444/OSHapp-Application)

## 2) Architecture et composants
- **Frontend**: Flutter (Web servi via Nginx)
  - Dossier: `frontend/`
  - Dockerfile: `frontend/Dockerfile` (build Flutter → Nginx `nginx:alpine`)
  - Port: `3000`
- **Backend**: Spring Boot (Java 17)
  - Dossier: `backend/`
  - Dockerfile: `backend/Dockerfile` (runtime `eclipse-temurin:17-jre-jammy`)
  - Port: `8081` (+ debug `5005`)
  - Profil: `docker`
- **Infra (Docker Compose)**: `backend/infra/docker-compose.yml`
  - Services: `postgres:16.4`, `mongo:6`, `minio/minio:latest`, `backend`, `frontend`
  - Volumes: `pgdata`, `mongodata`, `miniodata`, `mavenrepo`
- **Config principale (Docker)**: `backend/src/main/resources/application-docker.yml`
- **Docs API**: Swagger UI via SpringDoc
  - URL: `http://localhost:8081/swagger-ui/index.html` (après démarrage)

## 3) Prérequis de développement
- **Java 17** et **Maven >= 3.9**
- **Flutter stable** avec **Dart >= 3** (web activé)
- **Docker Desktop** (Compose v2)
- Accès Internet (dépendances Maven/pub.dev, images Docker de base)

## 4) Démarrage rapide (stack Docker de dev)
1. Créez un fichier `.env` à la racine de `backend/` (référencé par Compose via `../.env` depuis `backend/infra/`). Exemple:

```env
# Base de données
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=oshapp

# Backend DB
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/oshapp
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=postgres

# Mongo
MONGO_INITDB_DATABASE=oshapp

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin
KC_DB=postgres
KC_DB_URL=jdbc:postgresql://postgres:5432/oshapp
KC_DB_USERNAME=postgres
KC_DB_PASSWORD=postgres
KEYCLOAK_AUTH_SERVER_URL=http://keycloak:8080
KEYCLOAK_CLIENT_SECRET=CHANGE_ME

# App
APP_JWT_SECRET=CHANGE_ME
APP_JWT_EXPIRATIONMS=86400000
APP_FRONTEND_BASE_URL=oshapp://open
GOOGLE_SERVER_CLIENT_ID=CHANGE_ME

# Email
SPRING_MAIL_USERNAME=CHANGE_ME
SPRING_MAIL_PASSWORD=CHANGE_ME
```

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
## 5) Variables d’environnement (extrait utile)
Source: `backend/src/main/resources/application-docker.yml` et `backend/infra/docker-compose.yml`
- App JWT: `APP_JWT_SECRET`, `APP_JWT_EXPIRATIONMS`
- Frontend deep link/base URL: `APP_FRONTEND_BASE_URL`
- Google: `GOOGLE_SERVER_CLIENT_ID`
- Datasource: `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
- Email: `SPRING_MAIL_USERNAME`, `SPRING_MAIL_PASSWORD`
- Keycloak (app): `KEYCLOAK_AUTH_SERVER_URL`, `KEYCLOAK_CLIENT_SECRET`, `keycloak.realm=oshapp`, `keycloak.client-id=oshapp-backend`
- Keycloak (serveur): `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KC_DB`, `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`
- MinIO: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`

## 6) Dépendances
### 6.1 Frontend (pubspec.yaml — runtime)
- flutter (sdk)
- http: ^1.1.0
- http_parser: ^4.0.2
- shared_preferences: ^2.2.2
- flutter_appauth: ^9.0.1
- url_launcher: ^6.2.1
- flutter_secure_storage: ^9.0.0
- flutter_typeahead: ^5.2.0
- pin_code_fields: 8.0.1
- collection: ^1.18.0
- meta: ^1.15.0
- logger: ^2.0.0
- animated_background: ^2.0.0
- cupertino_icons: ^1.0.2
- flutter_localizations (sdk)
- get_it: ^7.6.7
- dio: ^5.4.0
- flutter_svg: ^2.0.10+1
- google_fonts: ^6.2.1
- font_awesome_flutter: ^10.7.0
- google_sign_in: 6.2.1
- provider: ^6.1.1
- retrofit: ^4.0.3
- json_annotation: ^4.8.1
- openid_client: ^0.4.9
- isar: ^3.1.0+1
- intl: ^0.20.2
- image_picker: ^1.0.4
- file_picker: ^8.0.0+1
- csv: ^5.0.2
- excel: ^2.0.4
- path_provider: ^2.1.1
- flutter_local_notifications: ^19.3.1
- firebase_messaging: ^16.0.0
- fl_chart: ^1.0.0
- syncfusion_flutter_charts: ^30.1.40
- syncfusion_flutter_pdfviewer: ^30.1.40
- pdf: ^3.10.7
- printing: ^5.11.1
- qr_flutter: ^4.1.0
- table_calendar: ^3.0.9
- timeago: ^3.6.0
- jwt_decoder: ^2.0.1
- shimmer: ^3.0.0
- google_nav_bar: ^5.0.6
- file_saver: ^0.3.1
- file_selector: ^1.0.3
- characters: ^1.3.0
- device_info_plus: ^11.5.0

### 6.2 Frontend (dev)
- flutter_lints: ^3.0.0
- build_runner: ^2.4.8
- json_serializable: ^6.8.0
- retrofit_generator: ^8.1.0
- isar_generator: ^3.1.0+1
- flutter_gen_runner: 5.4.0
- flutter_launcher_icons: ^0.13.1

### 6.3 Backend (pom.xml)
- spring-boot-starter-web
- spring-boot-starter-validation
- spring-boot-starter-thymeleaf
- spring-boot-starter-mail
- spring-boot-starter-data-jpa
- postgresql (runtime)
- spring-boot-starter-security
- spring-boot-starter-oauth2-resource-server
- spring-boot-devtools (runtime, optional)
- lombok (${lombok.version})
- spring-boot-starter-test (test)
- spring-security-test (test)
- springdoc-openapi-starter-webmvc-ui: 2.5.0
- jjwt-api / jjwt-impl (runtime) / jjwt-jackson: 0.11.5
- javax.annotation-api: 1.3.2
- swagger-annotations: 2.2.20
- mapstruct + mapstruct-processor: ${org.mapstruct.version}
- google-api-client: 2.6.0
- google-http-client-jackson2: 1.44.2

Build plugins clés: `maven-compiler-plugin`, `jacoco-maven-plugin`, `spring-boot-maven-plugin`, `maven-surefire-plugin`, `maven-failsafe-plugin`, `exec-maven-plugin`.

## 7) Build des images applicatives (prod)
Backend:
```bash
docker build -t oshapp-backend:0.0.1 -f backend/Dockerfile backend
```
Frontend (web + Nginx):
```bash
docker build -t oshapp-frontend:latest -f frontend/Dockerfile frontend
```

## 8) Export des images Docker (remise off-line)
```bash
# Backend
docker save oshapp-backend:0.0.1 -o guide/oshapp-backend-0.0.1.tar
# Frontend
docker save oshapp-frontend:latest -o guide/oshapp-frontend-latest.tar
```

## 9) Bases de données — liens et exports
- **PostgreSQL** (Base principale JPA)
  - Service: `postgres` (5432)
  - Export (depuis Docker):
    ```bash
    docker exec -t oshapp-postgres pg_dump -U postgres -d oshapp | gzip > guide/databases/oshapp_postgres.sql.gz
    ```
- **MongoDB** 
  - Service: `mongodb` (27017)
  - Export:
    ```bash
    docker exec oshapp-mongo mongodump --db oshapp --archive=guide/databases/oshapp_mongo.archive
    ```

## 10) Qualité, sécurité et bonnes pratiques
- **JWT**: définir `APP_JWT_SECRET` robuste, conserver hors dépôt.
- **OIDC**: `keycloak` (realm `oshapp`, client `oshapp-backend`). Mettre à jour `KEYCLOAK_CLIENT_SECRET`.
- **Mail**: utiliser un compte SMTP dédié (éviter comptes personnels).
- **Tests & couverture**: `jacoco-maven-plugin` configuré. Activer `mvn test` et publier rapports.
- **Mapping**: `MapStruct` activé (component model Spring).



## 12) Annexes
- Backend `application-docker.yml`: `backend/src/main/resources/application-docker.yml`
- Compose: `backend/infra/docker-compose.yml`
- Dockerfiles: `backend/Dockerfile`, `frontend/Dockerfile`
- Ports: Backend `8081` (debug `5005`), Keycloak `8080`, Postgres `5432`, Mongo `27017`, MinIO `9000/9001`, Frontend `3000`
