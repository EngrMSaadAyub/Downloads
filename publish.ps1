<#
.SYNOPSIS
    Publishes a new version of one of my tools to this public downloads repository.

.DESCRIPTION
    The tools' source code lives in their own (private) repositories; this repository only holds the downloads.
    Each release is tagged "<tool>-v<version>" (for example "my-pc-buddy-v1.3.0"). The script:
      1. adds or updates the tool in tools.json,
      2. keeps the release notes in notes\<tool>\<version>.md,
      3. rebuilds README.md (the table of tools with direct download links),
      4. commits and pushes that,
      5. creates the GitHub release with the files attached.
    Needs git and the GitHub CLI (gh), signed in with push access to this repository.

.EXAMPLE
    # First release of a new tool: give its name and a one-line description.
    .\publish.ps1 -Tool my-pc-buddy -Version 1.3.0 -File "..\My PC Buddy\dist\MyPCBuddy-1.3.0.zip" -Notes notes.md `
                  -Name "My PC Buddy" -Description "A little hiker who lives on your Windows desktop."

.EXAMPLE
    # A later release: name and description are remembered.
    .\publish.ps1 -Tool my-pc-buddy -Version 1.4.0 -File "..\My PC Buddy\dist\MyPCBuddy-1.4.0.zip" -Notes notes.md
#>
param(
    [Parameter(Mandatory = $true)][string]$Tool,          # short id: lowercase letters, digits and dashes
    [Parameter(Mandatory = $true)][string]$Version,       # e.g. 1.3.0
    [Parameter(Mandatory = $true)][string[]]$File,        # file(s) to attach (the first one is the main download)
    [string]$Notes,                                       # markdown release notes
    [string]$Name,                                        # display name (needed the first time)
    [string]$Description,                                 # one line (needed the first time)
    [string]$Requirements                                 # e.g. "Windows 10 1903+ / Windows 11" (optional)
)
# Cmdlet errors stop the script; native commands (git, gh) are checked by exit code instead, because Windows
# PowerShell turns their redirected error output into terminating errors under 'Stop'.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Run([scriptblock]$command, [string]$what) {
    $ErrorActionPreference = 'Continue'
    & $command
    if ($LASTEXITCODE) { throw "$what failed (exit code $LASTEXITCODE)." }
}

function Succeeds([scriptblock]$command) {
    $ErrorActionPreference = 'Continue'
    & $command 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
}

if ($Tool -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "Tool id '$Tool' should be lowercase words joined by dashes, e.g. my-pc-buddy." }
if ($Version -notmatch '^\d+(\.\d+){1,3}$') { throw "Version '$Version' should look like 1.3.0." }
$files = @(foreach ($f in $File) { (Resolve-Path -LiteralPath $f).Path }) # always an array (one file too)
$tag = "$Tool-v$Version"

$repo = gh repo view --json nameWithOwner -q .nameWithOwner
if (-not $repo) { throw "Couldn't read this repository from GitHub (is gh signed in?)." }
if (Succeeds { gh release view $tag --repo $repo }) { throw "Release $tag already exists." }
if (git status --porcelain) { throw "This repository has uncommitted changes; commit or discard them first." }
if (Succeeds { git rev-parse --abbrev-ref '@{u}' }) { Run { git pull --ff-only --quiet } 'git pull' }

# --- tools.json --------------------------------------------------------------------------------------------
$tools = @()
# (Windows PowerShell hands a JSON array over as one object: the extra pipe step unrolls it.)
if (Test-Path tools.json) { $tools = @(Get-Content tools.json -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ }) }
$entry = $tools | Where-Object { $_.id -eq $Tool } | Select-Object -First 1
if (-not $entry) {
    if (-not $Name -or -not $Description) { throw "'$Tool' is new: pass -Name and -Description the first time." }
    $entry = [pscustomobject]@{ id = $Tool; name = $Name; description = $Description; requirements = ''; version = ''; date = ''; files = @() }
    $tools += $entry
}
if ($Name) { $entry.name = $Name }
if ($Description) { $entry.description = $Description }
if ($Requirements) { $entry.requirements = $Requirements }
$entry.version = $Version
$entry.date = (Get-Date).ToString('yyyy-MM-dd')
$entry.files = @($files | ForEach-Object { Split-Path $_ -Leaf })
$tools = @($tools | Sort-Object name)

$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'tools.json'), (ConvertTo-Json -InputObject $tools -Depth 5), $utf8)

# --- Release notes -------------------------------------------------------------------------------------------
$notesDir = Join-Path $PSScriptRoot "notes\$Tool"
New-Item -ItemType Directory -Force $notesDir | Out-Null
$notesPath = Join-Path $notesDir "$Version.md"
if ($Notes) { Copy-Item -LiteralPath $Notes $notesPath -Force }
else { [IO.File]::WriteAllText($notesPath, "$($entry.name) $Version.`n", $utf8) }

# --- README.md -----------------------------------------------------------------------------------------------
$base = "https://github.com/$repo"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Downloads')
$lines.Add('')
$lines.Add('Free tools by Engr. Muhammad Saad Ayub. Pick a tool, download the file, and see its release notes (What''s new).')
$lines.Add('')
$lines.Add('| Tool | What it does | Latest | Download |')
$lines.Add('|---|---|---|---|')
foreach ($t in $tools) {
    $t_tag = "$($t.id)-v$($t.version)"
    $main = @($t.files)[0]
    $what = $t.description + $(if ($t.requirements) { " <br>*$($t.requirements)*" } else { '' })
    $lines.Add("| **$($t.name)** | $what | $($t.version) <br>$($t.date) | [$main]($base/releases/download/$t_tag/$main) <br>[What's new]($base/releases/tag/$t_tag) |")
}
$lines.Add('')
$lines.Add("Older versions: [all releases]($base/releases). Each release is tagged ``<tool>-v<version>``.")
$lines.Add('')
$lines.Add('Windows may warn about an unknown app the first time you run one: choose **More info** then **Run anyway**.')
$lines.Add('')
$lines.Add('Android apps (`.apk`): download the file on your phone and open it; allow installing from your browser or files')
$lines.Add('app when Android asks, then tap **Install**.')
$lines.Add('')
$lines.Add('## Publishing (for me)')
$lines.Add('')
$lines.Add('Build the tool in its own repository, then from here:')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('.\publish.ps1 -Tool <id> -Version <x.y.z> -File <path to zip> -Notes <notes.md>')
$lines.Add('```')
$lines.Add('')
$lines.Add('A new tool also needs `-Name` and `-Description`. The script updates `tools.json`, keeps the notes in')
$lines.Add('`notes/<id>/<version>.md`, rebuilds this README, pushes, and creates the release. See `publish.ps1` for details.')
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'README.md'), ($lines -join "`n") + "`n", $utf8)

# --- Commit, push, release -----------------------------------------------------------------------------------
Run { git add tools.json README.md "notes/$Tool/$Version.md" } 'git add'
if (-not (Succeeds { git diff --cached --quiet })) { Run { git commit --quiet -m "$($entry.name) $Version" } 'git commit' } # a rerun after a failed release has nothing new
Run { git push --quiet origin HEAD } 'git push'
$head = git rev-parse HEAD
Run { gh release create $tag @files --repo $repo --title "$($entry.name) $Version" --notes-file $notesPath --target $head } 'Creating the release'
Write-Host "Published: $base/releases/tag/$tag"
