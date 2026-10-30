<#
.SYNOPSIS
  Собирает setup-terminal.ps1 из src/: логика (src/setup-logic.ps1) + файлы, встроенные как here-strings.

.EXAMPLE
  .\build.ps1               # собрать из src/
.EXAMPLE
  .\build.ps1 -FromProfile  # сначала забрать в src/ текущую рабочую настройку с этой машины, потом собрать
#>
param([switch]$FromProfile)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$profileDir = Split-Path $PROFILE

# ключ во встроенных файлах → файл в src/ → где он живёт на машине
$files = [ordered]@{
    'profile'     = @('src\profile\Microsoft.PowerShell_profile.ps1', $PROFILE)
    'palette'     = @('src\profile\palette.ps1', (Join-Path $profileDir 'palette.ps1'))
    'toolkit'     = @('src\profile\toolkit.ps1', (Join-Path $profileDir 'toolkit.ps1'))
    'custom'      = @('src\profile\custom.ps1', $null)     # шаблон: ставится один раз, с машины не забирается
    'predictor'   = @('src\profile\DeepHistoryPredictor.cs', (Join-Path $profileDir 'DeepHistoryPredictor.cs'))
    'omp-theme'   = @('src\ohmyposh\soft.omp.json', (Join-Path $HOME '.config\ohmyposh\soft.omp.json'))
    'srv-bashrc'  = @('src\server\bashrc.local', (Join-Path $profileDir 'server\bashrc.local'))
    'srv-inputrc' = @('src\server\inputrc', (Join-Path $profileDir 'server\inputrc'))
    'srv-install' = @('src\server\install.sh', (Join-Path $profileDir 'server\install.sh'))
}
$utf8 = [Text.UTF8Encoding]::new($false)

if ($FromProfile) {
    foreach ($key in $files.Keys) {
        $src, $live = $files[$key]
        if (-not $live) { continue }
        $text = [IO.File]::ReadAllText($live) -replace "`r`n", "`n"
        [IO.File]::WriteAllText((Join-Path $root $src), $text, $utf8)
        "  ← $src"
    }
}

$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('# ── Встроенные файлы (собраны build.ps1 из src/) ────────────────────────────')
[void]$sb.AppendLine('$EmbeddedFiles = [ordered]@{}')
foreach ($key in $files.Keys) {
    $text = ([IO.File]::ReadAllText((Join-Path $root $files[$key][0])) -replace "`r`n", "`n").TrimEnd("`n")
    if ($text -match "(?m)^['`"]@") { throw "${key}: строка, начинающаяся с '@ или `"@, сломает here-string" }
    [void]$sb.AppendLine("`$EmbeddedFiles['$key'] = @'")
    [void]$sb.AppendLine($text)
    [void]$sb.AppendLine("'@")
}
$logic = [IO.File]::ReadAllText((Join-Path $root 'src\setup-logic.ps1')) -replace "`r`n", "`n"
$embedded = $sb.ToString().TrimEnd() -replace "`r`n", "`n"
$result = $logic.Replace('#@@EMBEDDED_FILES@@', $embedded)

$out = Join-Path $root 'setup-terminal.ps1'
# UTF-8 с BOM: иначе Windows PowerShell 5.1 прочитает кириллицу как cp1251 и сломается
[IO.File]::WriteAllText($out, $result, [Text.UTF8Encoding]::new($true))

$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($out, [ref]$null, [ref]$errors)
if ($errors) { $errors | ForEach-Object { "  ✗ строка $($_.Extent.StartLineNumber): $($_.Message)" }; throw 'setup-terminal.ps1 не разбирается' }
"  ✓ setup-terminal.ps1 — $([math]::Round((Get-Item $out).Length / 1KB)) КБ, синтаксис в порядке"
