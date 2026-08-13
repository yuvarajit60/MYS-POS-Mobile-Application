# Deploying AMSEL.MobileApi to the cloud

## Status
- **Database**: already cloud-hosted and reachable (`103.191.208.18`,
  database `db_ams_pos_test`) — confirmed working end-to-end (login,
  company lookup) against the real API code on 2026-08-09. No VPN/tunnel
  needed; this server already accepts remote connections.
- **`.env`**: filled in with the working connection string and a generated
  JWT signing key. Gitignored — never commit this file.
- **What's left**: deploy the API container itself to a cloud host.

## What's here
- `Dockerfile` — builds the API into a container image. Works with any
  Docker-capable host: Azure App Service (Web App for Containers), AWS App
  Runner/ECS, Render, Railway, DigitalOcean App Platform, or a plain VPS
  running Docker.
- `docker-compose.yml` + `.env.example` — local test run + the full list of
  environment variables the container needs (`.env` already has real
  values filled in locally, for reference when configuring the host).

## Steps

### 1. Local sanity check (optional but recommended)
Confirms the container itself builds and runs correctly before trusting a
cloud host's build process with it.
```
docker compose up --build
curl http://localhost:8080/health
curl http://localhost:8080/api/company
```

### 2. Pick a cloud host
Any Docker-capable provider works unchanged with this `Dockerfile`. If you
don't have a preference: Railway or Render are the least fiddly for a
first deployment (build straight from a Git push); Azure App Service for
Containers or AWS App Runner are good if you want to stay in a bigger
ecosystem.

### 3. Set the environment variables on the host
In the host's dashboard/secrets panel (not committed to git), set:
- `ConnectionStrings__MobileApiDb` = the value from `.env`'s
  `CONNECTION_STRING`
- `Jwt__SigningKey` = the value from `.env`'s `JWT_SIGNING_KEY`
- `Sms__Username` / `Sms__Password` = leave blank for now (no working SMS
  provider yet — OTP requests will 502 until this is set, same as local)

Note the double-underscore (`__`) — that's how ASP.NET Core reads
hierarchical config keys from flat environment variables.

### 4. Deploy
- **Git-push-to-deploy hosts** (Railway, Render): point them at this repo,
  set the build context to `AMSEL.MOBILE/AMSEL.MOBILEAPI` (where the
  `Dockerfile` lives), push.
- **Registry-based hosts** (Azure, AWS): build the image and push to the
  host's container registry, then point the App Service/App Runner at it.
  Happy to give exact commands once you've picked one.

### 5. Confirm it works
```
curl https://<your-deployed-url>/health
curl https://<your-deployed-url>/api/company
```
The second one should return the real company name if the connection
string made it through correctly.

### 6. Put HTTPS in front of it (if the host doesn't already provide it)
Most of the hosts above (Railway, Render, Azure App Service) give you
HTTPS automatically on their default domain. If you end up on a plain VPS
instead, you'll want Caddy or nginx+certbot in front — happy to give exact
config if you land there.

### 7. Send me the final URL
I'll swap it into `lib/core/api_client.dart`'s `baseUrl`, rebuild the APK,
and you're off the temporary ngrok tunnel for good.
