# Deploying AMSEL.MobileApi to the cloud (DB stays local for now)

Decision: SQL Server stays on this PC for the current dev/testing phase;
only the API service moves to the cloud. That means the cloud host needs a
secure way to reach back into this machine's database — **without**
exposing SQL Server's port (1433) directly on the public internet, which is
a real attack target (constant bot scanning/brute-force against exposed SQL
ports).

The clean way to do that regardless of which cloud provider you pick:
**Tailscale** — a private network (built on WireGuard) that connects this
PC and the cloud VM directly, so the cloud app reaches the database over a
private IP that nothing else on the internet can see or touch. Free for
this scale of use.

## What's already prepared here
- `Dockerfile` — builds the API into a container image.
- `docker-compose.yml` + `.env.example` — local test run + the full list of
  environment variables the container needs.

## Steps

### 1. Install Tailscale on this PC
- Download from tailscale.com, install, sign in (any Google/Microsoft/GitHub
  account works — a personal account is fine, separate from any cloud
  billing account).
- Once running, it assigns this PC a private Tailscale IP (looks like
  `100.x.y.z`). Find it with `tailscale ip` or the Tailscale tray icon.

### 2. Make sure SQL Server accepts TCP connections on a fixed port
- Open **SQL Server Configuration Manager** → SQL Server Network
  Configuration → Protocols for SQLEXPRESS → enable **TCP/IP**.
- Right-click TCP/IP → Properties → IP Addresses tab → scroll to **IPAll**
  → clear "TCP Dynamic Ports", set **TCP Port** to a fixed value (`1433` if
  nothing else is using it).
- Restart the SQL Server (SQLEXPRESS) service for the change to apply.
- Windows Firewall: allow that port, but **only from the Tailscale network
  interface** (not a general internet-facing rule) — Tailscale creates its
  own virtual network adapter you can scope the firewall rule to.

### 3. Provision a small cloud VM (any provider)
- Any provider works — DigitalOcean, AWS Lightsail, Azure, Linode, etc.
  Cheapest tier is plenty (this API is lightweight).
- Pick Ubuntu as the OS (simplest for the next steps).

### 4. On the VM: install Docker and Tailscale
```
curl -fsSL https://get.docker.com | sudo sh
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
- Sign in with the **same Tailscale account** used on this PC — the VM and
  this PC now share a private network.

### 5. Get this PC's Tailscale IP and use it in the connection string
- From step 1, e.g. `100.101.102.103`.
- The container's `CONNECTION_STRING` env var becomes:
  `Server=100.101.102.103,1433;Database=db_ams_erp;User Id=<user>;Password=<password>;TrustServerCertificate=True;`

### 6. Copy the project and deploy the container on the VM
```
git clone <wherever this repo lives>   # or scp the AMSEL.MOBILEAPI folder over
cd AMSEL.MOBILE/AMSEL.MOBILEAPI
cp .env.example .env      # fill in the real connection string (step 5), JWT key, SMS creds
docker compose up --build -d
```

### 7. Confirm it works
```
curl http://localhost:8080/health
```
From your own phone/laptop: `curl http://<vm-public-ip>:8080/health`
(open port 8080 in the VM's cloud firewall/security-group settings first).

### 8. Put a real domain + HTTPS in front of it (recommended before real use)
A raw `http://ip:8080` URL works for testing but isn't great long-term.
Cheapest path: point a domain at the VM and run **Caddy** or **nginx +
certbot** in front of the container for free automatic HTTPS. Happy to
provide exact config for this once you're at that step.

### 9. Send me the final URL
Once you have a stable URL (with or without HTTPS), I'll update
`lib/core/api_client.dart`'s `baseUrl` to point at it, rebuild the APK, and
you're off the temporary ngrok tunnel for good.

## Local sanity check (optional, before touching any cloud VM)
```
cp .env.example .env
docker compose up --build
curl http://localhost:8080/health
```
