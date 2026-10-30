$global:TerminalSetupVersion = '2.2.0'
$global:ProfileDir = Split-Path $PROFILE
$env:XDG_CONFIG_HOME = "$HOME\.config"
$global:isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'

$global:TerminalSetup = @{
    Abbreviations = $true
    LayoutFix     = $true
    Predictions   = 50
}

. (Join-Path $ProfileDir 'palette.ps1')
. (Join-Path $ProfileDir 'lang.ps1')
$global:ThemeName = Get-ThemeName
$global:Palette = $CatppuccinFlavors[$ThemeName]
$env:TERMINAL_THEME = $ThemeName
$global:LangName = Get-LangName
$global:TkStr = $Strings[$LangName]

. (Join-Path $ProfileDir 'toolkit.ps1')
Set-TerminalPalette

$before = @(Get-ChildItem Function: | Select-Object -ExpandProperty Name)
$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) {
    try { . $customFile } catch { Write-Warning "custom.ps1: $_" }
}
$global:CustomFunctions = @(Get-ChildItem Function: | Where-Object { $_.Name -notin $before -and $_.Name -notmatch ':' } | Select-Object -ExpandProperty Name)
Remove-Variable before, customFile
Register-BinCommands (Join-Path $ProfileDir 'bin')

if ($isInteractive) {
    try {
        Set-PSReadLineOption -EditMode Emacs `
            -HistoryNoDuplicates `
            -HistorySearchCursorMovesToEnd `
            -MaximumHistoryCount 20000 `
            -BellStyle None `
            -PredictionSource History `
            -PredictionViewStyle ListView
    } catch { Write-Warning "PSReadLine: $_" }
    Set-TerminalPalette

    Set-PSReadLineKeyHandler -Key Tab             -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+c          -Function CancelLine
    Set-PSReadLineKeyHandler -Key UpArrow         -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow       -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key F2              -Function SwitchPredictionView
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace  -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Delete     -Function KillWord
    Set-PSReadLineKeyHandler -Key Ctrl+z          -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+y          -Function Redo
    Set-PSReadLineKeyHandler -Key Shift+Enter     -Function AddLine
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'CheatSheet' -ScriptBlock { Invoke-HelpPicker }

    if ($TerminalSetup.Abbreviations) {
        Set-PSReadLineKeyHandler -Key Spacebar -BriefDescription 'ExpandAbbreviation' -ScriptBlock {
            $line = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            $exp = Expand-Abbreviation $line $cursor
            if ($exp) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace($exp.Start, $exp.Length, $exp.Text)
                if ($exp.Cursor -ge 0) { [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($exp.Cursor); return }
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert(' ')
        }
    }

    # History predictor plugin: PSReadLine caps built-in history suggestions at 10, plugins get 50.
    # The DLL is cached by source hash because a loaded DLL stays locked by open sessions.
    $predictorSrc = Join-Path $ProfileDir 'DeepHistoryPredictor.cs'
    if ($TerminalSetup.Predictions -gt 0 -and (Test-Path $predictorSrc)) {
        try {
            if (-not ('DeepHistoryPredictor' -as [type])) {
                $predictorHash = (Get-FileHash $predictorSrc -Algorithm SHA256).Hash.Substring(0, 12)
                $predictorDll = "$HOME\.cache\pwsh-predictor\DeepHistoryPredictor-$predictorHash.dll"
                if (-not (Test-Path $predictorDll)) {
                    New-Item -ItemType Directory -Force (Split-Path $predictorDll) | Out-Null
                    Add-Type -Path $predictorSrc -OutputAssembly $predictorDll -OutputType Library
                }
                Add-Type -Path $predictorDll
            }
            $predictorKind = [System.Management.Automation.Subsystem.SubsystemKind]::CommandPredictor
            if (-not ((Get-PSSubsystem -Kind CommandPredictor).Implementations | Where-Object Id -eq ([DeepHistoryPredictor]::PredictorId))) {
                [System.Management.Automation.Subsystem.SubsystemManager]::RegisterSubsystem(
                    $predictorKind, [DeepHistoryPredictor]::new((Get-PSReadLineOption).HistorySavePath, [Math]::Min(50, $TerminalSetup.Predictions)))
            }
            Set-PSReadLineOption -PredictionSource Plugin
        } catch {
            Write-Warning "DeepHistoryPredictor: $_"
        }
    }
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try { oh-my-posh init pwsh --config "$HOME\.config\ohmyposh\soft.omp.json" | Invoke-Expression }
    catch { Write-Warning "oh-my-posh: $_" }
}

# Enter: layout fix + abbreviation, then oh-my-posh's transient prompt (its handler is not chainable,
# so Set-TransientPrompt is called from the module scope) and AcceptLine.
if ($isInteractive -and ($TerminalSetup.LayoutFix -or $TerminalSetup.Abbreviations)) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'TerminalSetupEnter' -ScriptBlock {
        $line = $null; $cursor = $null; $errors = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($TerminalSetup.LayoutFix -and $line) {
            $fixed = Repair-CommandLayout $line
            if ($fixed) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $fixed); $line = $fixed; $cursor = $fixed.Length }
        }
        if ($TerminalSetup.Abbreviations) {
            $exp = Expand-Abbreviation $line $cursor
            if ($exp) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($exp.Start, $exp.Length, $exp.Text) }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$null, [ref]$null, [ref]$errors, [ref]$null)
        $omp = Get-Module oh-my-posh-core
        if ($omp -and $errors.Count -eq 0) { try { & $omp { Set-TransientPrompt } } catch {} }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        if ($global:_ompFTCSMarks -and $errors.Count -eq 0) { Write-Host "$([char]27)]133;C$([char]7)" -NoNewline }
    }
}

$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_CTRL_R_OPTS = '--height=14'
if ($isInteractive -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    # PSFzf auto-loads on first use; importing it eagerly costs ~0.3 s at startup
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'FolderNavigator' -ScriptBlock { nav; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try { Invoke-Expression (& { (zoxide init powershell | Out-String) }) } catch { Write-Warning "zoxide: $_" }
}

$env:BAT_THEME = 'ansi'
$env:BAT_STYLE = 'numbers,changes,header-filename'

$completionCache = "$HOME\.cache\pwsh-completions"
$completionGenerators = [ordered]@{
    kubectl  = { kubectl completion powershell }
    helm     = { helm completion powershell }
    kind     = { kind completion powershell }
    k3d      = { k3d completion powershell }
    minikube = { minikube completion powershell }
    docker   = { docker completion powershell }
    gh       = { gh completion -s powershell }
}
function Update-Completions {
    New-Item -ItemType Directory -Force $completionCache | Out-Null
    foreach ($name in $completionGenerators.Keys) {
        $file = Join-Path $completionCache "$name.ps1"
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            & $completionGenerators[$name] | Out-String | Set-Content $file -Encoding utf8
            Write-Host "  ✓ $name" -ForegroundColor Green
        } elseif (Test-Path $file) {
            Remove-Item $file
        }
    }
}
if (-not (Test-Path $completionCache)) { Update-Completions | Out-Null }
foreach ($file in Get-ChildItem $completionCache -Filter *.ps1) {
    try { . $file.FullName } catch { Write-Warning "$($file.Name): $_" }
}

$ezaArgs = '--icons=auto', '--group-directories-first', '--color=always'
function l   { eza @ezaArgs @args }
function ll  { eza @ezaArgs -la --git --time-style=relative --no-user @args }
function lt  { eza @ezaArgs --tree --level=2 --git-ignore @args }
function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function mkcd($path) { New-Item -ItemType Directory -Force $path | Out-Null; Set-Location $path }
function which($name) { Get-Command $name -All | Select-Object CommandType, Name, Source }
function touch($path) { if (Test-Path $path) { (Get-Item $path).LastWriteTime = Get-Date } else { New-Item -ItemType File $path | Out-Null } }
function lg  { git log --graph --pretty='%C(magenta)%h%Creset %C(green)%ar%Creset %C(blue)%an%Creset %s%C(yellow)%d%Creset' -n 30 @args }
function gst { git status -sb @args }
function reload { . $PROFILE }
