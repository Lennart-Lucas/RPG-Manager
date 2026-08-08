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
        DeployHost = $deployHost
        User = $user
        RepoPath = $repoPath
        SshKeyPath = $sshKeyPath
    }
}

function Get-RemoteDeployCommand {
    param([string]$RepoPath)

    $repoPath = $RepoPath.TrimEnd("/")
    $sshUrl = $GitHubSshUrl
    # Single-line remote script so PowerShell → OpenSSH quoting stays reliable.
    # Echoes mark each phase; Docker build is the long step (Flutter web).
    return (
        "set -e; " +
        "echo '==> [1/4] Checking git remote...'; " +
        "cd $repoPath; " +
        "current=`$(git remote get-url origin 2>/dev/null || true); " +
        "if [ `"`$current`" != `"$sshUrl`" ]; then " +
        "git remote set-url origin $sshUrl 2>/dev/null || git remote add origin $sshUrl; " +
        "fi; " +
        "echo '==> [2/4] Fetching origin/main...'; " +
        "if ! git fetch origin; then " +
        "echo RPG_MANAGER_DEPLOY_GIT_AUTH_FAILED >&2; exit 42; " +
        "fi; " +
        "echo '==> [3/4] Resetting working tree to origin/main...'; " +
        "git reset --hard origin/main; " +
        "cd backend; " +
        "echo '==> [4/4] Building containers (Flutter web can take 10-20+ min on first build)...'; " +
        "echo '    Live Docker output follows; idle gaps during layer downloads are normal.'; " +
        "DOCKER_BUILDKIT=1 docker compose --progress=plain -p rpg-manager-prod -f docker-compose.prod.yml up --build -d; " +
        "echo '==> Remote deploy steps finished.'"
    )
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
    Write-Host "Streaming remote output live (this can take a long time during Docker/Flutter builds)."
    Write-Host ""

    $sshArgs = @(
        "-i", $SshKeyPath,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "StrictHostKeyChecking=accept-new",
        # Force remote stdout/stderr through without TTY allocation issues.
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
        # Only blame GitHub deploy-key setup when the failure looks like git auth,
        # not a generic SSH BatchMode/passphrase denial during VPS login.
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
        throw "Remote deploy failed (ssh exit code $exitCode)."
    }
}

$config = Get-DeployConfig
$remoteCommand = Get-RemoteDeployCommand -RepoPath $config.RepoPath

Write-Host "Deploying RPG-Manager backend to $($config.User)@$($config.DeployHost)..."
Write-Host "Repo path: $($config.RepoPath)"
Write-Host "Auth: SSH key ($($config.SshKeyPath))"
Write-Host ""

Invoke-RemoteViaOpenSsh `
    -User $config.User `
    -DeployHost $config.DeployHost `
    -SshKeyPath $config.SshKeyPath `
    -RemoteCommand $remoteCommand

Write-Host ""
Write-Host "Deploy finished successfully."
