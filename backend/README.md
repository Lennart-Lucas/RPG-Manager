# RPG Manager Backend

FastAPI API with PostgreSQL, Alembic migrations, and Docker.

## Local development

```powershell
cd backend
.\scripts\setup.ps1
.\scripts\dev.ps1 up
```

- API: http://localhost:8011/docs
- Health: http://localhost:8011/health
- Postgres (host): localhost:5435

Compose project: `rpg-manager-dev`.

```powershell
.\scripts\dev.ps1 logs
.\scripts\dev.ps1 down
.\scripts\dev.ps1 migrate
```

## Production (local prod-like stack)

Requires **Flutter on PATH** (the player website is built on this machine, not inside Docker).

```powershell
.\scripts\setup.ps1
# Edit .env.prod — set POSTGRES_PASSWORD and matching DATABASE_URL values
.\scripts\prod.ps1 up
```

`prod.ps1 up` runs `build-web.ps1` (Flutter web → `backend/static/web`), then builds a lightweight API image that copies those files.

Compose project: `rpg-manager-prod`. API + player website on host port **8011**.

- Website: http://localhost:8011/
- API docs (dev image only): not exposed in production
- Health: http://localhost:8011/health

## Remote server deployment

Deploy from your Windows machine to a Linux host with Docker. The website is built **locally** (Flutter), uploaded with `scp`, then the VPS only builds a small Python API image — safe for small droplets (1 vCPU / 2 GB).

### One-time local setup

```powershell
cd backend
Copy-Item .deploy.local.example .deploy.local
notepad .deploy.local   # set DEPLOY_HOST and DEPLOY_SSH_KEY_PATH
```

Requires **OpenSSH** (`ssh` / `scp` / `ssh-add` on PATH) and **Flutter** on PATH. The deploy script starts `ssh-agent` and runs `ssh-add` for your deploy key before connecting (you'll be prompted for the passphrase if needed). If starting the agent fails, run once in elevated PowerShell: `Set-Service ssh-agent -StartupType Manual`.

`.deploy.local` holds **VPS** SSH access only — not GitHub tokens.

### One-time server setup

```bash
# Clone once (use SSH URL — required for private repos)
git clone git@github.com:Lennart-Lucas/RPG-Manager.git ~/RPG-Manager
cd ~/RPG-Manager/backend
cp .env.prod.example .env.prod
nano .env.prod          # set POSTGRES_PASSWORD, JWT_SECRET, matching DATABASE_* URLs
```

Do **not** run `docker compose up --build` on the VPS alone for the first website deploy — the image expects `backend/static/web` from the Windows deploy script. Use `.\scripts\deploy-remote.ps1` from your PC after pushing to `main` (that builds web locally, uploads it, then starts compose).

### Private repository setup (deploy key)

If the GitHub repo is private, the VPS must authenticate to GitHub with a **read-only deploy key**:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/rpg_manager_deploy -N ""
cat ~/.ssh/rpg_manager_deploy.pub
```

1. GitHub → RPG-Manager → **Settings → Deploy keys → Add deploy key** (read-only). Paste the public key.
2. Configure SSH on the VPS:

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/rpg_manager_deploy
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/rpg_manager_deploy
```

3. Ensure the clone uses the SSH remote and verify fetch:

```bash
cd ~/RPG-Manager
git remote set-url origin git@github.com:Lennart-Lucas/RPG-Manager.git
git fetch origin
```

Public repos work without a deploy key; the deploy script still normalizes `origin` to the SSH URL.

### Deploy latest `main`

Push your changes to GitHub first, then:

```powershell
cd backend
# if needed: ssh-add $env:USERPROFILE\.ssh\id_ed25519
.\scripts\deploy-remote.ps1
```

Or pass credentials for this session only:

```powershell
$env:DEPLOY_HOST = 'YOUR_IP'
$env:DEPLOY_SSH_KEY_PATH = 'C:\Users\you\.ssh\id_ed25519'
.\scripts\deploy-remote.ps1
```

The script:

1. Builds Flutter web on this PC (`build-web.ps1`)
2. SSHs to the VPS → `git fetch` + `reset --hard origin/main`
3. Uploads `backend/static/web` via `scp`
4. Rebuilds/restarts the prod stack (API-only Docker build; migrations in the entrypoint)

### Verify on server

```bash
curl -s http://localhost:8011/health
curl -sI http://localhost:8011/ | head
docker compose -p rpg-manager-prod -f docker-compose.prod.yml ps
```

Player website: `http://YOUR_IP:8011/` (register as a player on web; use the desktop app as DM).

### Shared campaign (1-campaign server)

Catalog data is shared across accounts on this server:

- The **earliest active DM** (`is_dm=true`) owns the campaign catalog automatically.
- **Players** read that catalog; only DMs can create / edit / delete.
- Desktop register creates a DM; web register creates a player.

Promote an existing user to DM if needed:

```sql
UPDATE users SET is_dm = true WHERE email = 'dm@example.com';
```

Optional escape hatch (rarely needed): pin a specific owner in `.env.prod` with
`CAMPAIGN_OWNER_USER_ID=<id>`. If no DM exists yet, each user keeps their own
catalog (solo/local).
