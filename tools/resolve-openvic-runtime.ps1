$ErrorActionPreference = "Stop"

function Resolve-OpenVicGodot {
    foreach ($candidate in @(
        $env:OPENVIC_GODOT_EXE,
        [Environment]::GetEnvironmentVariable("OPENVIC_GODOT_EXE", "User")
    )) {
        if ($candidate -and (Test-Path $candidate)) {
            $version = (& $candidate --version 2>&1 | Select-Object -First 1).ToString().Trim()
            if ($version -match '^4\.7\.2') {
                return (Resolve-Path $candidate).Path
            }
        }
    }

    $root = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    foreach ($exe in @(Get-ChildItem $root -Recurse -File -Filter "Godot*.exe" -ErrorAction SilentlyContinue)) {
        try {
            $version = (& $exe.FullName --version 2>&1 | Select-Object -First 1).ToString().Trim()
            if ($version -match '^4\.7\.2') {
                return $exe.FullName
            }
        } catch {}
    }

    return $null
}

function Test-OpenVicVictoria2Root([string]$Path) {
    if (-not $Path -or -not (Test-Path $Path -PathType Container)) { return $false }
    return (Test-Path (Join-Path $Path "common\goods.txt")) -and
           (Test-Path (Join-Path $Path "map\default.map"))
}

function Resolve-OpenVicVictoria2 {
    foreach ($candidate in @(
        $env:OPENVIC_VIC2_PATH,
        [Environment]::GetEnvironmentVariable("OPENVIC_VIC2_PATH", "User")
    )) {
        if (Test-OpenVicVictoria2Root $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem)) {
        foreach ($library in @(
            (Join-Path $drive.Root "SteamLibrary"),
            (Join-Path $drive.Root "Steam"),
            (Join-Path $drive.Root "Program Files (x86)\Steam"),
            (Join-Path $drive.Root "Program Files\Steam")
        )) {
            $manifest = Join-Path $library "steamapps\appmanifest_42960.acf"
            if (-not (Test-Path $manifest)) { continue }

            $text = Get-Content -Raw $manifest
            $match = [regex]::Match($text, '"installdir"\s*"([^"]+)"')
            if (-not $match.Success) { continue }

            $root = Join-Path $library ("steamapps\common\" + $match.Groups[1].Value)
            if (Test-OpenVicVictoria2Root $root) {
                return (Resolve-Path $root).Path
            }
        }
    }

    return $null
}