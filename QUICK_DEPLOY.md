# 🚀 Quick Deployment Guide

Follow these steps to deploy Aivus to a fresh server (Ubuntu/Debian recommended).

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

## 4. Troubleshooting

*   **Logs:** `docker compose -f docker-compose.production.yml logs -f`
*   **Status:** `docker compose -f docker-compose.production.yml ps`
*   **Restart:** `docker compose -f docker-compose.production.yml restart`
