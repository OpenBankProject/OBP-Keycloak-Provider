# Local Development Onboarding

A step-by-step guide to running the **OBP Keycloak Provider** locally from a fresh
start. Follow it top to bottom the first time; later runs are just step 3.

## What this is

A Keycloak User Storage SPI that authenticates users via the **OBP REST API**
instead of a database. Keycloak still needs its *own* PostgreSQL database for
realm/session state — that is separate from anything OBP. Authentication
(username lookup + credential verification) is delegated to OBP over HTTP.

```
Host machine                 Docker container (host network)        PostgreSQL (host)
  .env, themes/, src/  --->   Keycloak 26.5.x + provider.jar  <-->   keycloakdb
                              |  authenticates via OBP REST  |
                                          |
                                          v
                                   OBP API (:8080)
```

---

## Prerequisites (install once)

| Tool | Why | Notes |
|------|-----|-------|
| **Docker** | builds & runs the Keycloak image | daemon must be running |
| **Maven** 3.8.5+ | builds the provider JAR | |
| **JDK 17+** | the provider targets Java 17 | The deploy script auto-detects an installed JDK 17/21 even if your shell default is older (e.g. Java 11) — it just has to be installed. |
| **PostgreSQL** | Keycloak's internal database | local or remote; reachable from the host |
| **git**, **curl** | clone & health checks | `psql` handy but optional |

---

## 1. Start the external services

### a) PostgreSQL — and create the Keycloak database

The deploy script **tests** the DB connection but does **not** create the database.
Create the database that `KC_DB_URL` points to (Keycloak builds its own tables inside it):

```bash
createdb -h localhost -U postgres keycloakdb
# ensure the KC_DB_USERNAME role exists and can connect to keycloakdb
```

### b) OBP API

Have an OBP API instance reachable at `OBP_API_URL` (default `http://localhost:8080`).

> Keycloak will still **start** without it (the script only warns), but **every login
> fails until OBP is reachable** — authentication is delegated to OBP. The OBP admin
> account in `.env` must hold the roles `CanGetAnyUser`, `CanVerifyUserCredentials`
> (and `CanGetOidcClient`).

---

## 2. Configure `.env`

```bash
cp env.sample .env
# then edit .env
```

> ⚠️ **Gotcha:** the deploy script requires `KEYCLOAK_VERSION`, but `env.sample` does
> not include it. Add it or the run aborts with *"Missing variable: KEYCLOAK_VERSION"*:
> ```
> KEYCLOAK_VERSION=26.5.3
> ```

Mandatory values to fill in:

| Variable | Meaning |
|----------|---------|
| `KC_DB_URL` / `KC_DB_USERNAME` / `KC_DB_PASSWORD` | Keycloak's internal Postgres (e.g. `jdbc:postgresql://host.docker.internal:5432/keycloakdb`) |
| `OBP_API_URL` | base URL of the OBP API (no trailing slash) |
| `OBP_API_USERNAME` / `OBP_API_PASSWORD` | OBP admin account with the required roles |
| `OBP_API_CONSUMER_KEY` | consumer key registered in OBP for Direct Login |
| `OBP_AUTHUSER_PROVIDER` | **hard-required** — only users with this `provider` value authenticate |
| `KEYCLOAK_VERSION` | Keycloak base image tag (see gotcha above) |

Optional: `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` (default `admin`/`admin`),
ports, `FORGOT_PASSWORD_URL`. See `env.sample` for the full reference.

---

## 3. Deploy

```bash
./development/run-local-postgres-cicd.sh           # standard
./development/run-local-postgres-cicd.sh --themed  # keep OBP themes in the image
```

The script runs an 8-step pipeline: validate env → test connectivity → Maven build
(Java 17) → stop/remove old container → build image → start → health check. It uses
`--network host`, so Keycloak binds host ports directly.

### Access

| URL | Purpose |
|-----|---------|
| `https://localhost:8443/admin` | Admin console |
| `http://localhost:7787` | HTTP |
| `https://localhost:9000/health/ready` | health endpoint |

Default admin: `admin` / `admin` (unless overridden in `.env`).

The provider appears under **User federation → `obp-keycloak-provider`**.

---

## 4. First-login notes (fresh database)

Two things are **runtime state in `keycloakdb`**, not in the repo — a brand-new
database won't have them:

1. **"Update Account Information" prompt on first admin login.** The bootstrap admin
   has no first/last name, so Keycloak 26 forces a one-time profile completion
   (`VERIFY_PROFILE`). Just fill in name + email once and you're in permanently.
2. **The login language dropdown is OFF by default.** The theme ships translated
   bundles for `en, de, fr, es, it, pt, ja, zh-CN`, but each realm must opt in:
   **Realm settings → Localization → Internationalization ON**, select locales, Save.

---

## 5. Manage & tear down

```bash
./development/manage-container.sh     # interactive menu (status, logs, restart, remove)
docker logs -f obp-keycloak-local     # follow logs
docker restart obp-keycloak-local     # restart (keeps the container's filesystem)
docker rm -f obp-keycloak-local       # remove container (Postgres data persists)
```

A full reset = remove the container **and** drop/recreate `keycloakdb`.

---

## 6. Logging & observability

The deploy script wires a few logging/maintenance knobs (all set in `.env`, no
rebuild needed unless noted):

| Variable | Default | Purpose |
|----------|---------|---------|
| `KC_LOG_LEVEL` | `INFO` | Root log level. Supports category overrides, e.g. `INFO,io.tesobe:DEBUG` to debug only the OBP provider, or `io.tesobe:ERROR` to mute its noise. |
| `KC_LOG_CONSOLE_OUTPUT` | `default` | `default` = human text; `json` = structured logs for aggregators (Loki / ELK / CloudWatch). |
| `DOCKER_LOG_MAX_SIZE` | `10m` | Max size of each container log file before rotation. |
| `DOCKER_LOG_MAX_FILE` | `5` | Number of rotated log files kept (caps disk usage). |

Common tasks:

- **Identify the running build.** Every container prints a banner at startup —
  the JAR checksum + build timestamp baked into the image:
  ```bash
  docker logs obp-keycloak-local | grep -A2 'OBP Keycloak Provider build'
  ```
- **Debug just the OBP provider** without flooding everything else:
  ```
  KC_LOG_LEVEL=INFO,io.tesobe:DEBUG      # in .env, then redeploy
  ```
- **Ship to a log aggregator:** `KC_LOG_CONSOLE_OUTPUT=json`.
- **Health & metrics** (already enabled): `https://localhost:9000/health/ready`
  and `https://localhost:9000/metrics` (Prometheus format — point a scraper at it).

> ⚠️ **Known log-noise caveat:** the provider currently emits routine activity
> (e.g. `isValid() … password validation SUCCESSFUL`, `FEDERATED STORAGE DETECTED`)
> at **WARN**, and logs user names/emails at INFO/WARN. Until that's fixed in the
> provider code, you can quiet it operationally with `KC_LOG_LEVEL=…,io.tesobe:ERROR`.
> Don't treat WARN volume as a health signal yet.

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `Missing variable: KEYCLOAK_VERSION` | add `KEYCLOAK_VERSION=...` to `.env` |
| `invalid target release: 17` | no JDK 17+ installed; install `openjdk-17-jdk` |
| `Keycloak DB is unreachable — cannot continue` | Postgres not running, or `keycloakdb` not created, or `KC_DB_URL` wrong |
| Keycloak starts but every login fails | OBP API not reachable, or OBP creds/roles wrong, or `OBP_AUTHUSER_PROVIDER` doesn't match the user's provider in OBP |
| `OBP_AUTHUSER_PROVIDER is mandatory` | set it in `.env` |
| Login page shows raw message keys | theme message bundle issue — ensure `themes/obp/login/theme.properties` has `parent=base` |
| Port conflicts (7787/8443/9000) | `netstat -tulpn | grep -E ':(7787|8443|9000)'`; stop the conflicting process |

---

## Related docs

- [README.md](../README.md) — project overview & key environment variables
- [development/README.md](../development/README.md) — deploy/manage scripts reference
- [docs/CICD_DEPLOYMENT.md](CICD_DEPLOYMENT.md) — CI/CD deployment
- [env.sample](../env.sample) — full environment variable reference
