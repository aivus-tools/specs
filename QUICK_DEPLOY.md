# 🚀 Quick Deployment Guide

Follow these steps to deploy Aivus to a fresh server (Ubuntu/Debian recommended).

## ⚠️ Important: Safe Re-installation

**The install script is SAFE to re-run!** It will:
- ✅ Detect existing installation
- ✅ Preserve all secrets and passwords
- ✅ Create backups before overwriting
- ✅ Ask for confirmation before regenerating secrets

**Never lose your database password again!**

## 1. Prerequisites

You need:
*   A server with public IP
*   A domain pointing to that IP (A record)
*   GCP Service Account JSON key (`gcp-credentials.json`)

## 2. Deployment Steps

### Step 1: Prepare the Server
SSH into your server:
```bash
ssh user@your-server-ip
```

### Step 2: Upload GCP Credentials
Copy your GCP JSON key to the server:
```bash
# Run this FROM YOUR LOCAL MACHINE
scp path/to/gcp-credentials.json user@your-server-ip:~/
```

### Step 3: Run the Installer
On the server, run this one-liner to download and start the installation:
```bash
curl -sSL https://raw.githubusercontent.com/ipolotsky/Aivus/main/Specs/deployment/install.sh | bash
```
*(Note: Replace the URL with the actual raw URL of your `install.sh` if different)*

**What the script does:**
- Installs/updates Docker to a compatible version (24.0.0+)
- Installs Docker Compose
- Generates secure passwords and Basic Auth credentials (with proper escaping for Traefik)
- Creates docker-compose.production.yml with all services
- Sets up Traefik with automatic SSL
- Configures pgAdmin, Flower, Mailpit with Basic Auth protection

### Step 4: Follow the Prompts
The script will ask for:
1.  **Domain** (e.g., `aivus.co`)
2.  **Email** (for SSL certificates)
3.  **GCP Credentials** location (it will look for `~/gcp-credentials.json` by default)

### Step 5: Finalize
Once the script finishes:
1.  **Check Credentials:**
    ```bash
    cat ~/aivus/CREDENTIALS.txt
    ```
    *Save these! They include database passwords and admin logins.*

2.  **Start Services:**
    ```bash
    cd ~/aivus
    docker compose -f docker-compose.production.yml up -d
    ```

3.  **Initialize App:**
    ```bash
    # Run migrations
    docker compose -f docker-compose.production.yml exec django python manage.py migrate
    
    # Create admin user
    docker compose -f docker-compose.production.yml exec django python manage.py createsuperuser
    ```

## 3. Verification
Open your browser and check:
*   Frontend: `https://go.aivus.co` (or your APP_DOMAIN)
*   API: `https://go.aivus.co/api/v1/`
*   Traefik Dashboard: `https://traefik.aivus.co` (or your SERVICE_DOMAIN)
*   Flower: `https://flower.aivus.co`
*   pgAdmin: `https://pgadmin.aivus.co`

## 4. Database Backup & Restore

The deployment includes Postgres maintenance scripts for easy backup and restore:

### Create a Backup
```bash
docker compose -f docker-compose.production.yml exec postgres backup
```

### List Backups
```bash
docker compose -f docker-compose.production.yml exec postgres backups
```

### Restore from Backup
```bash
docker compose -f docker-compose.production.yml exec postgres restore backup_2024_01_15T10_30_00.sql.gz
```

### Remove a Backup
```bash
docker compose -f docker-compose.production.yml exec postgres rmbackup backup_2024_01_15T10_30_00.sql.gz
```

Backups are stored in the `postgres_backups` volume and persist across container restarts.

## 5. Versions

*   **Docker:** 24.0.0+ (auto-installed/updated by script)
*   **Postgres:** 17
*   **Traefik:** 2.11 (stable, compatible with older Docker API)
*   **Redis:** 7-alpine
*   **Python:** 3.13
*   **Node.js:** (as per frontend Dockerfile)

**Note:** The install script automatically checks and updates Docker to version 24.0.0+ if needed. We use Traefik 2.11 for maximum compatibility.

## 6. Re-running the Installer

If you need to update configuration or reinstall:

```bash
cd ~/aivus
./install.sh
```

The script will:
1. **Detect existing installation**
2. **Ask what you want to do:**
   - Option 1: Keep existing secrets (SAFE - recommended)
   - Option 2: Generate new secrets (requires database recreation)
   - Option 3: Exit to backup manually

3. **Create backups** of `.env` and `CREDENTIALS.txt` with timestamps

**Example scenario:**
```bash
# You want to update domain or add OAuth keys
./install.sh
# Choose option 1 (keep secrets)
# Update only what you need
# Restart services
docker compose -f docker-compose.production.yml restart
```

## 7. Manual Backup (Recommended)

Before major changes, create manual backups:

```bash
# Backup configuration
cp ~/aivus/.env ~/aivus/.env.manual.backup
cp ~/aivus/CREDENTIALS.txt ~/aivus/CREDENTIALS.txt.manual.backup

# Backup database
docker compose -f docker-compose.production.yml exec postgres backup

# Download backups to local machine
scp user@server:~/aivus/.env.manual.backup ./
scp user@server:~/aivus/CREDENTIALS.txt.manual.backup ./
```

## 8. Troubleshooting

*   **Logs:** `docker compose -f docker-compose.production.yml logs -f`
*   **Status:** `docker compose -f docker-compose.production.yml ps`
*   **Restart:** `docker compose -f docker-compose.production.yml restart`
*   **Lost credentials?** Check backup files: `ls -la ~/aivus/*.backup*`
