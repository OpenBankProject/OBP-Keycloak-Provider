````markdown
# OBP-Keycloak-provider: Build & Run Script

This repository includes a Bash script to **build, run, and manage** the `obp-keycloak-provider` Docker container.  
It automates building the Maven project, creating a Docker image, running the container, and cleaning up old resources.

---

## What it does

The script performs these steps:

1. Loads environment variables from `.env`
2. Builds the Maven project (skipping tests)
3. Stops & removes any previously running container with the same name
4. Removes the old Docker image (if it exists)
5. Builds a new Docker image
6. Starts a new container from the image
7. Follows the logs of the running container

---

## Requirements

- **Docker** (tested with Docker 20+)
- **Maven** (tested with Maven 3.9+)
- **Bash** (Linux or MacOS)
- A `.env` file in the project root containing:
  ```ini
  KC_BOOTSTRAP_ADMIN_USERNAME=your_admin_username
  KC_BOOTSTRAP_ADMIN_PASSWORD=your_admin_password
````

> Warning: Move any other secrets you need here too.

---

## Usage

1. Make the script executable:

   ```bash
   chmod +x your-script-name.sh
   ```

2. Run it:

   ```bash
   ./your-script-name.sh
   ```

The script will:

* Build your project and Docker image
* Stop & remove the old container and image (if any)
* Start a fresh container
* Show the last 100 lines of logs and follow new log output

---

## Configuration

Default configuration inside the script:

| Variable         | Default                       | Purpose                      |
| ---------------- |-------------------------------| ---------------------------- |
| `IMAGE_NAME`     | `obp-keycloak-provider-image` | Name of the Docker image     |
| `CONTAINER_NAME` | `obp-keycloak-provider-container`   | Name of the Docker container |
| `EXTERNAL_PORT`  | `8443`                        | Port exposed on the host     |
| `INTERNAL_PORT`  | `8443`                        | Port inside the container    |
| `DOCKERFILE`     | `docker/Dockerfile`           | Path to the Dockerfile       |
| `ENV_FILE`       | `.env`                        | Path to the environment file |

You can adjust these directly in the script.

---

## Cleanup logic

The script **only** stops & removes:

* the container named `obp-keycloak-provider-container`
* the Docker image named `obp-keycloak-provider-image` (if it exists)

This ensures it doesn’t interfere with other containers or images on your system.

---

## Health check

The container runs with a health check that pings:

```
https://127.0.0.1:8443/health/ready
```

every 30 seconds, with retries and timeout.