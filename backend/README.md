# RPG Manager Backend

FastAPI API with PostgreSQL, Alembic migrations, and Docker.

## Local development

```powershell
cd Backend
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

```powershell
.\scripts\setup.ps1
# Edit .env.prod — set POSTGRES_PASSWORD and matching DATABASE_URL values
.\scripts\prod.ps1 up
```

Compose project: `rpg-manager-prod`. API on host port **8011**.

## Remote server deployment

Deploy from your Windows machine to a Linux host with Docker. VPS credentials stay in a gitignored local file.

### One-time local setup

```powershell
cd Backend
Copy-Item .deploy.local.example .deploy.local
notepad .deploy.local   # set DEPLOY_HOST and DEPLOY_SSH_KEY_PATH
```

Requires **OpenSSH** (`ssh` on PATH). `.deploy.local` holds **VPS** SSH access only — not GitHub tokens.

### One-time server setup

```bash
# Clone once (use SSH URL — required for private repos)
git clone git@github.com:Lennart-Lucas/RPG-Manager.git ~/RPG-Manager
cd ~/RPG-Manager/Backend
cp .env.prod.example .env.prod
nano .env.prod          # set POSTGRES_PASSWORD and matching DATABASE_* URLs
docker compose -p rpg-manager-prod -f docker-compose.prod.yml up --build -d
```

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
cd Backend
.\scripts\deploy-remote.ps1
```

Or pass credentials for this session only:

```powershell
$env:DEPLOY_HOST = 'YOUR_IP'
$env:DEPLOY_SSH_KEY_PATH = 'C:\Users\you\.ssh\id_ed25519'
.\scripts\deploy-remote.ps1
```

The script SSHs to the VPS, ensures the SSH git remote, runs `git fetch` + `git reset --hard origin/main`, and rebuilds the prod stack. Migrations run in the container entrypoint.

### Verify on server

```bash
curl -s http://localhost:8011/health
docker compose -p rpg-manager-prod -f docker-compose.prod.yml ps
```
