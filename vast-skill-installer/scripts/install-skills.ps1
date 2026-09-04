param (
    [Parameter(Mandatory = $false)]
    [string[]]$RepoUrls,

    [Parameter(Mandatory = $false)]
    [ValidateSet("seo", "dev", "all", "custom")]
    [string]$Preset = "seo",

    [Parameter(Mandatory = $false)]
    [string]$TargetDir = ".agents/skills"
)

$ErrorActionPreference = "Stop"

# 内置预设技能库字典
$Presets = @{
    "seo" = @(
        "https://github.com/VastFuture/backlink_skills",
        "https://github.com/VastFuture/yan-skills"
    )
    "dev" = @(
        "https://github.com/VastFuture/vast-dev-skill"
    )
    "all" = @(
        "https://github.com/VastFuture/backlink_skills",
        "https://github.com/VastFuture/yan-skills",
        "https://github.com/VastFuture/vast-dev-skill"
    )
}

# 决策最终待安装的 URL 列表
$FinalUrls = @()
if ($RepoUrls -and $RepoUrls.Count -gt 0) {
    $FinalUrls = $RepoUrls
} else {
    Write-Host "[Info] No specific RepoUrls provided. Using default preset: [$Preset]" -ForegroundColor Yellow
    $FinalUrls = $Presets[$Preset]
}

$ResolvedTarget = Resolve-Path -Path $TargetDir -ErrorAction SilentlyContinue
if (-not $ResolvedTarget) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    $ResolvedTarget = (Resolve-Path -Path $TargetDir).Path
} else {
    $ResolvedTarget = $ResolvedTarget.Path
}

$TempBase = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "vast-skill-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempBase -Force | Out-Null

try {
    foreach ($url in $FinalUrls) {
        $repoName = ($url.TrimEnd('/') -split '/')[-1].Replace(".git", "")
        Write-Host "==> Downloading $repoName from $url..." -ForegroundColor Cyan

        $tempCloneDir = Join-Path $TempBase $repoName
        git clone --depth 1 $url $tempCloneDir

        if (-not (Test-Path $tempCloneDir)) {
            Write-Error "Failed to clone repository from $url"
            continue
        }

        # Remove git metadata from temp dir before copying
        $gitDir = Join-Path $tempCloneDir ".git"
        if (Test-Path $gitDir) {
            Remove-Item -Path $gitDir -Recurse -Force
        }

        $destDir = Join-Path $ResolvedTarget $repoName
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Copy clean files
        robocopy $tempCloneDir $destDir /E /XD .git | Out-Null
        if ($LASTEXITCODE -gt 7) {
            Write-Warning "Robocopy encountered errors copying $repoName (Exit code: $LASTEXITCODE)"
        }

        # Clean any accidental orphaned git artifacts
        $gitJunk = @("HEAD", "config", "description", "index", "packed-refs", "shallow", "hooks", "info", "logs", "objects", "refs")
        foreach ($junk in $gitJunk) {
            $junkPath = Join-Path $destDir $junk
            if (Test-Path $junkPath) {
                Remove-Item -Path $junkPath -Recurse -Force
            }
        }

        Write-Host "[OK] Installed $repoName to $destDir" -ForegroundColor Green
    }
} finally {
    if (Test-Path $TempBase) {
        Remove-Item -Path $TempBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "All requested skills have been installed cleanly." -ForegroundColor Green
