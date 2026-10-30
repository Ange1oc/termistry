$global:TerminalSetupVersion = '2.3.0'
$global:TerminalSetupLoaded = $false
$global:ProfileDir = Split-Path $PROFILE
$env:XDG_CONFIG_HOME = "$HOME\.config"
$global:isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'
$cacheDir = "$HOME\.cache\terminal-setup"

$global:TerminalSetup = @{
    Abbreviations = $true
    LayoutFix     = $true
    Predictions   = 50
}

. (Join-Path $ProfileDir 'palette.ps1')
$global:ThemeName = Get-ThemeName
$global:Palette = $Themes[$ThemeName]
$env:TERMINAL_THEME = $ThemeName
$langFile = Join-Path $HOME '.config\terminal-setup\lang'
$global:LangName = if ((Test-Path $langFile) -and (Get-Content $langFile -First 1).Trim() -eq 'en') { 'en' } elseif ((Test-Path $langFile) -or (Get-Culture).TwoLetterISOLanguageName -eq 'ru') { 'ru' } else { 'en' }

. (Join-Path $ProfileDir 'toolkit.ps1')
if (-not $isInteractive) { Set-TerminalPalette }

# The rest (strings, commands, completions, zoxide) loads after the first prompt is drawn.
# Those files declare everything as global: because they are dot-sourced from inside this function.
function global:Complete-TerminalSetup {
    if ($global:TerminalSetupLoaded) { return }
    $global:TerminalSetupLoaded = $true
    . (Join-Path $global:ProfileDir 'lang.ps1')
    $global:TkStr = $global:Strings[$global:LangName]
    . (Join-Path $global:ProfileDir 'toolkit-lazy.ps1')
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        $zoxideInit = "$HOME\.cache\terminal-setup\zoxide-init.ps1"
        $zoxideExe = (Get-Command zoxide).Source
        if (-not (Test-Path $zoxideInit) -or (Get-Item $zoxideInit).LastWriteTime -lt (Get-Item $zoxideExe).LastWriteTime) {
            New-Item -ItemType Directory -Force (Split-Path $zoxideInit) | Out-Null
            zoxide init powershell | Set-Content $zoxideInit -Encoding utf8
        }
        try { . $zoxideInit } catch { Write-Warning "zoxide: $_" }
    }
    $completions = "$HOME\.cache\pwsh-completions"
    $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction SilentlyContinue)
    if (-not (Test-Path $completions) -or ($files | Where-Object { (Get-Content $_.FullName -First 1) -ne '# global' })) {
        Update-Completions | Out-Null
        $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction SilentlyContinue)
    }
    foreach ($file in $files) {
        try { . $file.FullName } catch { Write-Warning "$($file.Name): $_" }
    }
    $null = Get-TsPreview
}
# Until then these names forward to the real functions on first use
foreach ($n in 'help', 'my', 'h', 'jump', 'srv', 'theme', 'lang', 'new', 'nav', 'pv', 'rgi', 'pk', 'gbr', 'o', 'doctor', 'update', 'ex', 'bak', 'psg', 'cb', 'ep', 'Invoke-HelpPicker', 'Update-Completions', 'Get-TsPreview') {
    Set-Item "Function:global:$n" -Value ([scriptblock]::Create("Complete-TerminalSetup; & '$n' @args"))
}

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
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'CheatSheet' -ScriptBlock { Complete-TerminalSetup; Invoke-HelpPicker }

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

# Prompt: oh-my-posh renders it, but its own `init` script costs ~0.4 s to evaluate on every start.
# This is the same call it makes, without the module around it. Transient prompt: see the Enter handler.
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $global:TsOmp = (Get-Command oh-my-posh).Source
    $global:TsOmpConfig = "$HOME\.config\ohmyposh\soft.omp.json"
    $env:POSH_THEME = $TsOmpConfig
    $env:POSH_SHELL = 'pwsh'
    $global:TsTransient = $false
    $global:TsLastHistoryId = 0
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    function global:prompt {
        $ok = $?
        $code = if ($ok) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
        $ms = 0
        $last = Get-History -Count 1
        if ($last -and $last.Id -ne $global:TsLastHistoryId) {
            $global:TsLastHistoryId = $last.Id
            $ms = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
        }
        $width = $Host.UI.RawUI.WindowSize.Width
        $kind = if ($global:TsTransient) { $global:TsTransient = $false; 'transient' } else { 'primary' }
        $out = & $global:TsOmp print $kind --shell pwsh --config $global:TsOmpConfig --pwd $PWD.ProviderPath --terminal-width $width --status $code --execution-time $ms
        $out -join "`n"
    }
}

# Enter: layout fix + abbreviation, redraw the prompt in its transient form, then run
if ($isInteractive -and ($TerminalSetup.LayoutFix -or $TerminalSetup.Abbreviations -or $global:TsOmp)) {
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
        if ($global:TsOmp -and $errors.Count -eq 0) {
            $global:TsTransient = $true
            try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch { $global:TsTransient = $false }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_CTRL_R_OPTS = '--height=14'
$env:FZF_CTRL_T_OPTS = "--height=70% --preview=`"$cacheDir\preview.cmd {}`" --preview-window=right:55%"
if ($isInteractive -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    # PSFzf auto-loads on first use; importing it eagerly costs ~0.3 s at startup
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'FolderNavigator' -ScriptBlock { Complete-TerminalSetup; nav; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
}

$env:BAT_THEME = 'ansi'
$env:BAT_STYLE = 'numbers,changes,header-filename'

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

if ($isInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -SupportEvent -Action { Complete-TerminalSetup }
} else {
    Complete-TerminalSetup
}
