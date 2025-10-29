<#
Simple PowerShell helper to initialize the local git repository, create the initial commit
and push to a remote. You must provide the remote URL (HTTPS or SSH).

Usage examples:
  # interactive
  .\scripts\git-init.ps1

  # non-interactive
  .\scripts\git-init.ps1 -RemoteUrl "git@github.com:username/repo.git" -Branch main
#>

param(
  [string]$RemoteUrl = $(Read-Host 'Remote Git URL (e.g. git@github.com:username/repo.git or https://github.com/username/repo.git)'),
  [string]$Branch = 'main'
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git no está disponible en PATH. Instala Git y vuelve a intentarlo."
  exit 1
}

if (-not (Test-Path ".git")) {
  git init
  git checkout -b $Branch
} else {
  Write-Host ".git ya existe — usando repo existente"
}

git add .
git commit -m "chore: initial commit"

if ($RemoteUrl) {
  git remote remove origin -ErrorAction SilentlyContinue
  git remote add origin $RemoteUrl
  git push -u origin $Branch
  Write-Host "Pushed to $RemoteUrl on branch $Branch"
} else {
  Write-Host "No remote URL provided. Repo initialized locally."
}
