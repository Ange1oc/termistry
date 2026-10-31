<#
.SYNOPSIS
  Builds setup-terminal.ps1 from src/: the installer logic plus every profile file embedded as a here-string.

.EXAMPLE
  .\build.ps1               # build from src/
.EXAMPLE
  .\build.ps1 -FromProfile  # pull the working setup from this machine into src/ first, then build
#>
param([switch]$FromProfile)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$profileDir = Split-Path $PROFILE

# installed path (relative to the profile folder) → source in src/
$files = [ordered]@{
    'Microsoft.PowerShell_profile.ps1' = 'src\profile\Microsoft.PowerShell_profile.ps1'
    'palette.ps1'                      = 'src\profile\palette.ps1'
    'lang.ps1'                         = 'src\profile\lang.ps1'
    'toolkit.ps1'                      = 'src\profile\toolkit.ps1'
    'toolkit-lazy.ps1'                 = 'src\profile\toolkit-lazy.ps1'
    'prompt.ps1'                       = 'src\profile\prompt.ps1'
    'workspace.ps1'                    = 'src\profile\workspace.ps1'
    'DeepHistoryPredictor.cs'          = 'src\profile\DeepHistoryPredictor.cs'
    'server\bashrc.local'              = 'src\server\bashrc.local'
    'server\inputrc'                   = 'src\server\inputrc'
    'server\install.sh'                = 'src\server\install.sh'
    'custom.ps1'                       = 'src\profile\custom.ps1'   # template: written once, never overwritten, never pulled back
}
$utf8 = [Text.UTF8Encoding]::new($false)

if ($FromProfile) {
    foreach ($rel in $files.Keys) {
        if ($rel -eq 'custom.ps1') { continue }
        $text = [IO.File]::ReadAllText((Join-Path $profileDir $rel)) -replace "`r`n", "`n"
        [IO.File]::WriteAllText((Join-Path $root $files[$rel]), $text, $utf8)
        "  ← $($files[$rel])"
    }
}

$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('# Embedded files, put here by build.ps1 from src/')
[void]$sb.AppendLine('$EmbeddedFiles = [ordered]@{}')
foreach ($rel in $files.Keys) {
    $text = ([IO.File]::ReadAllText((Join-Path $root $files[$rel])) -replace "`r`n", "`n").TrimEnd("`n")
    if ($text -match "(?m)^['`"]@") { throw "$($files[$rel]): a line starting with '@ or `"@ would end the here-string" }
    [void]$sb.AppendLine("`$EmbeddedFiles['$rel'] = @'")
    [void]$sb.AppendLine($text)
    [void]$sb.AppendLine("'@")
}
$logic = [IO.File]::ReadAllText((Join-Path $root 'src\setup-logic.ps1')) -replace "`r`n", "`n"
$embedded = $sb.ToString().TrimEnd() -replace "`r`n", "`n"
$version = [regex]::Match([IO.File]::ReadAllText((Join-Path $root 'src\profile\Microsoft.PowerShell_profile.ps1')), "TermistryVersion = '([^']+)'").Groups[1].Value
$result = $logic.Replace('#@@EMBEDDED_FILES@@', $embedded).Replace('__VERSION__', $version)

$out = Join-Path $root 'setup-terminal.ps1'
# UTF-8 with BOM: Windows PowerShell 5.1 reads a BOM-less file as cp1251 and breaks on Cyrillic
[IO.File]::WriteAllText($out, $result, [Text.UTF8Encoding]::new($true))

$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($out, [ref]$null, [ref]$errors)
if ($errors) { $errors | ForEach-Object { "  ✗ line $($_.Extent.StartLineNumber): $($_.Message)" }; throw 'setup-terminal.ps1 does not parse' }
"  ✓ setup-terminal.ps1 v$version, $([math]::Round((Get-Item $out).Length / 1KB)) KB, parses"
