[CmdletBinding()]
param(
  [string]$RuntimeDir = (Join-Path $env:TEMP 'siye-stack-runtime'),
  [string]$MusicApiSource = '',
  [string]$LinuxServerJar = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Resolve-RequiredPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path).Path
}

$labSource = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$frontendKnowledgeRoot = (Resolve-Path -LiteralPath (Join-Path $labSource '..\..\..')).Path
$localProjectsRoot = Split-Path -Parent $frontendKnowledgeRoot

if (-not $MusicApiSource) {
  $MusicApiSource = Join-Path $localProjectsRoot 'NeteaseCloudMusicApi-private'
}

if (-not $LinuxServerJar) {
  $LinuxServerJar = Join-Path $localProjectsRoot 'java-project\linux-server\target\linux-server-0.0.1-SNAPSHOT.jar'
}

$musicSource = Resolve-RequiredPath -Path $MusicApiSource -Label 'music-api source directory'
$jarSource = Resolve-RequiredPath -Path $LinuxServerJar -Label 'linux-server JAR'
$runtimePath = [System.IO.Path]::GetFullPath($RuntimeDir)
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')

if (-not $runtimePath.StartsWith("$tempRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Runtime directory must be under the system temp directory: $tempRoot"
}

if (Test-Path -LiteralPath $runtimePath) {
  if (-not $Force) {
    throw "Runtime directory already exists: $runtimePath. Add -Force to rebuild it."
  }
  Remove-Item -LiteralPath $runtimePath -Recurse -Force
}

Copy-Item -LiteralPath $labSource -Destination $runtimePath -Recurse

$runtimeMusicSource = Join-Path $runtimePath 'NeteaseCloudMusicApi-private'
robocopy $musicSource $runtimeMusicSource /E /XD node_modules .git .claude | Out-Host
if ($LASTEXITCODE -ge 8) {
  throw "Failed to copy music-api source, robocopy exit code: $LASTEXITCODE"
}

$runtimeJar = Join-Path $runtimePath 'linux-server\linux-server-0.0.1-SNAPSHOT.jar'
Copy-Item -LiteralPath $jarSource -Destination $runtimeJar -Force

$runtimeEnv = Join-Path $runtimePath '.env'
Copy-Item -LiteralPath (Join-Path $runtimePath '.env.example') -Destination $runtimeEnv -Force

$runtimeLogs = Join-Path $runtimePath 'runtime-logs'
New-Item -ItemType Directory -Path $runtimeLogs -Force | Out-Null

@(
  'music-api.log',
  'music-api-error.log',
  'socket.log',
  'socket-error.log'
) | ForEach-Object {
  New-Item -ItemType File -Path (Join-Path $runtimeLogs $_) -Force | Out-Null
}

Write-Host ''
Write-Host 'Lab 6 runtime directory is ready:'
Write-Host $runtimePath
Write-Host ''
Write-Host 'Next: update passwords and base image addresses in .env, then run docker compose config.'
