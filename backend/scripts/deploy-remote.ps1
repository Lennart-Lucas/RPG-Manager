$ErrorActionPreference = "Stop"

$GitHubSshUrl = "git@github.com:Lennart-Lucas/RPG-Manager.git"
$PrivateRepoHint = @"
Private repo auth failed on the server (git fetch / SSH to GitHub).

One-time fix on the VPS — see backend/README.md (Private repository setup):
  1. ssh-keygen -t ed25519 -f ~/.ssh/rpg_manager_deploy -N ""
  2. Add the public key as a read-only Deploy key on RPG-Manager
  3. Point ~/.ssh/config Host github.com at that IdentityFile
  4. Ensure origin is $GitHubSshUrl and run: git fetch origin
"@

function Read-DeployLocalFile {
    param([string]$Path)

    $values = @{}
    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) {
            continue
        }
        $eq = $trimmed.IndexOf("=")
        if ($eq -lt 1) {
            continue
        }
        $key = $trimmed.Substring(0, $eq).Trim()
        $value = $trimmed.Substring($eq + 1).Trim()
        $values[$key] = $value
    }
    return $values
}

function Resolve-DeployPath {
    param(
        [string]$Path,
        [string]$BackendRoot
    )

    if (-not $Path) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }

    return (Join-Path $BackendRoot $expanded)
}

function Get-DeployConfig {
    $backendRoot = Split-Path $PSScriptRoot -Parent
    $localFile = Join-Path $backendRoot ".deploy.local"

    $deployHost = $env:DEPLOY_HOST
    $user = $env:DEPLOY_USER
    $repoPath = $env:DEPLOY_REPO_PATH
    $sshKeyPath = $env:DEPLOY_SSH_KEY_PATH

    if (Test-Path $localFile) {
        $fileValues = Read-DeployLocalFile -Path $localFile
        if (-not $deployHost) { $deployHost = $fileValues["DEPLOY_HOST"] }
        if (-not $user) { $user = $fileValues["DEPLOY_USER"] }
        if (-not $repoPath) { $repoPath = $fileValues["DEPLOY_REPO_PATH"] }
        if (-not $sshKeyPath) { $sshKeyPath = $fileValues["DEPLOY_SSH_KEY_PATH"] }
    }

    if (-not $user) { $user = "root" }
    if (-not $repoPath) { $repoPath = "~/RPG-Manager" }
    $sshKeyPath = Resolve-DeployPath -Path $sshKeyPath -BackendRoot $backendRoot

    if (-not $deployHost) {
        throw "DEPLOY_HOST is required. Set `$env:DEPLOY_HOST or add it to .deploy.local."
    }
    if (-not $sshKeyPath) {
        throw "DEPLOY_SSH_KEY_PATH is required. Set it in .deploy.local (VPS SSH key)."
    }
    if (-not (Test-Path $sshKeyPath)) {
        throw "SSH private key not found: $sshKeyPath"
    }

    return @{
        BackendRoot = $backendRoot
        DeployHost = $deployHost
        User = $user
        RepoPath = $repoPath
        SshKeyPath = $sshKeyPath
    }
}

function Invoke-RemoteViaOpenSsh {
    param(
        [string]$User,
        [string]$DeployHost,
        [string]$SshKeyPath,
        [string]$RemoteCommand
    )

    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $ssh) {
        throw "OpenSSH (ssh) is required on PATH."
    }

    Write-Host "Using OpenSSH to connect to ${User}@${DeployHost}..."
    Write-Host "Streaming remote output live."
    Write-Host ""

    $sshArgs = @(
        "-i", $SshKeyPath,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "RequestTTY=no",
        "${User}@${DeployHost}",
        $RemoteCommand
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $ssh.Source @sshArgs 2>&1 | ForEach-Object {
            $text = "$_"
            [void]$lines.Add($text)
            Write-Host $text
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $output = ($lines -join [Environment]::NewLine)

    if ($exitCode -eq 42 -or ($output -match "RPG_MANAGER_DEPLOY_GIT_AUTH_FAILED")) {
        throw $PrivateRepoHint
    }
    if ($exitCode -ne 0) {
        if ($output -match "RPG_MANAGER_DEPLOY_GIT_AUTH_FAILED|Could not read from remote repository|Repository not found") {
            throw $PrivateRepoHint
        }
        if ($output -match "Permission denied \(publickey\)" -and $output -notmatch "docker|Building|Dockerfile") {
            throw (
                "SSH to the VPS failed (publickey). " +
                "If your key has a passphrase, run: ssh-add `"$SshKeyPath`" " +
                "then retry. Interactive ssh works; this script cannot prompt for a passphrase."
            )
        }
        throw "Remote command failed (ssh exit code $exitCode)."
    }
}

function Invoke-ScpUpload {
    param(
        [string]$User,
        [string]$DeployHost,
        [string]$SshKeyPath,
        [string]$LocalPath,
        [string]$RemotePath
    )

    $scp = Get-Command scp -ErrorAction SilentlyContinue
    if (-not $scp) {
        throw "OpenSSH (scp) is required on PATH."
    }

    Write-Host "Uploading $LocalPath -> ${User}@${DeployHost}:$RemotePath ..."
    $scpArgs = @(
        "-i", $SshKeyPath,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "StrictHostKeyChecking=accept-new",
        "-r",
        $LocalPath,
        "${User}@${DeployHost}:$RemotePath"
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        & $scp.Source @scpArgs 2>&1 | ForEach-Object {
            $text = "$_"
            [void]$lines.Add($text)
            Write-Host $text
        }
        if ($LASTEXITCODE -ne 0) {
            $joined = $lines -join [Environment]::NewLine
            if ($joined -match "Permission denied") {
                throw (
                    "SCP failed (publickey). Run: ssh-add `"$SshKeyPath`" then retry."
                )
            }
            throw "SCP upload failed (exit code $LASTEXITCODE)."
        }
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

$config = Get-DeployConfig
$repoPath = $config.RepoPath.TrimEnd("/")
$sshUrl = $GitHubSshUrl
$staticWebLocal = Join-Path $config.BackendRoot "static\web"
$buildWebScript = Join-Path $PSScriptRoot "build-web.ps1"

Write-Host "Deploying RPG-Manager to $($config.User)@$($config.DeployHost)..."
Write-Host "Repo path: $($config.RepoPath)"
Write-Host "Auth: SSH key ($($config.SshKeyPath))"
Write-Host ""

Write-Host "==> Phase A: Build Flutter web on this machine"
& $buildWebScript
if (-not (Test-Path (Join-Path $staticWebLocal "index.html"))) {
    throw "Local web build missing index.html at $staticWebLocal"
}
Write-Host ""

Write-Host "==> Phase B: Update git on the server"
$gitRemote = (
    "set -e; " +
    "echo '==> Checking git remote...'; " +
    "cd $repoPath; " +
    "current=`$(git remote get-url origin 2>/dev/null || true); " +
    "if [ `"`$current`" != `"$sshUrl`" ]; then " +
    "git remote set-url origin $sshUrl 2>/dev/null || git remote add origin $sshUrl; " +
    "fi; " +
    "echo '==> Fetching origin/main...'; " +
    "if ! git fetch origin; then " +
    "echo RPG_MANAGER_DEPLOY_GIT_AUTH_FAILED >&2; exit 42; " +
    "fi; " +
    "echo '==> Resetting to origin/main...'; " +
    "git reset --hard origin/main; " +
    "mkdir -p backend/static; " +
    "rm -rf backend/static/web; " +
    "echo '==> Server ready for static upload.'"
)
Invoke-RemoteViaOpenSsh `
    -User $config.User `
    -DeployHost $config.DeployHost `
    -SshKeyPath $config.SshKeyPath `
    -RemoteCommand $gitRemote
Write-Host ""

Write-Host "==> Phase C: Upload prebuilt website"
# Places local backend/static/web as remote .../backend/static/web
Invoke-ScpUpload `
    -User $config.User `
    -DeployHost $config.DeployHost `
    -SshKeyPath $config.SshKeyPath `
    -LocalPath $staticWebLocal `
    -RemotePath "$repoPath/backend/static/"
Write-Host ""

Write-Host "==> Phase D: Rebuild API image on the server (no Flutter; should be quick)"
$composeRemote = (
    "set -e; " +
    "cd $repoPath/backend; " +
    "if [ ! -f static/web/index.html ]; then " +
    "echo 'Missing static/web/index.html after upload' >&2; exit 1; " +
    "fi; " +
    "echo '==> docker compose up --build (API-only image)...'; " +
    "DOCKER_BUILDKIT=1 docker compose --progress=plain -p rpg-manager-prod -f docker-compose.prod.yml up --build -d; " +
    "echo '==> Remote deploy finished.'; " +
    "curl -sS http://localhost:8011/health || true; " +
    "echo; " +
    "curl -sSI http://localhost:8011/ | head -n 5 || true"
)
Invoke-RemoteViaOpenSsh `
    -User $config.User `
    -DeployHost $config.DeployHost `
    -SshKeyPath $config.SshKeyPath `
    -RemoteCommand $composeRemote

Write-Host ""
Write-Host "Deploy finished successfully."
Write-Host "Website: http://$($config.DeployHost):8011/"
Write-Host "Health:  http://$($config.DeployHost):8011/health"
