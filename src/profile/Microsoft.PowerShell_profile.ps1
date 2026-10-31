$global:TermistryVersion = '1.0.1'
$global:TermistryLoaded = $false
$global:TsFiles = 'Microsoft.PowerShell_profile.ps1', 'palette.ps1', 'lang.ps1', 'toolkit.ps1', 'toolkit-lazy.ps1', 'prompt.ps1', 'workspace.ps1', 'DeepHistoryPredictor.cs', 'server\bashrc.local', 'server\inputrc', 'server\install.sh'
$global:ProfileDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PROFILE }
$env:XDG_CONFIG_HOME = "$HOME\.config"
$global:isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'
$cacheDir = "$HOME\.cache\termistry"

$global:Termistry = @{
    Abbreviations = $true
    LayoutFix     = $true
    Predictions   = 50
    GitStatus     = $true
    Kube          = 'auto'
    Workspace     = $true
}
# custom.ps1 written before the rename sets $TerminalSetup.*
$global:TerminalSetup = $global:Termistry

. (Join-Path $ProfileDir 'palette.ps1')
$global:ThemeName = Get-ThemeName
$global:Palette = $Themes[$ThemeName]
$env:TERMINAL_THEME = $ThemeName
$langFile = Join-Path $HOME '.config\termistry\lang'
$global:LangName = if ((Test-Path $langFile) -and (Get-Content $langFile -First 1).Trim() -eq 'en') { 'en' } elseif ((Test-Path $langFile) -or (Get-Culture).TwoLetterISOLanguageName -eq 'ru') { 'ru' } else { 'en' }

. (Join-Path $ProfileDir 'toolkit.ps1')
if (-not $isInteractive) { Set-TerminalPalette }

# The rest (strings, commands, completions, zoxide) loads after the first prompt is drawn.
# Those files declare everything as global: because they are dot-sourced from inside this function.
function global:Complete-Termistry {
    if ($global:TermistryLoaded) { return }
    $global:TermistryLoaded = $true
    . (Join-Path $global:ProfileDir 'lang.ps1')
    $global:TkStr = $global:Strings[$global:LangName]
    . (Join-Path $global:ProfileDir 'toolkit-lazy.ps1')
    . (Join-Path $global:ProfileDir 'workspace.ps1')
    if (Find-TkCommand zoxide) {
        $zoxideInit = "$HOME\.cache\termistry\zoxide-init.ps1"
        $zoxideExe = (Get-Command zoxide).Source
        if (-not (Test-Path $zoxideInit) -or (Get-Item $zoxideInit).LastWriteTime -lt (Get-Item $zoxideExe).LastWriteTime) {
            New-Item -ItemType Directory -Force (Split-Path $zoxideInit) | Out-Null
            zoxide init powershell | Set-Content $zoxideInit -Encoding utf8
        }
        try { . $zoxideInit } catch { Write-Warning "zoxide: $_" }
    }
    $completions = "$HOME\.cache\pwsh-completions"
    $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction Ignore)
    if (-not (Test-Path $completions) -or ($files | Where-Object { (Get-Content $_.FullName -First 1) -ne '# global' })) {
        Update-Completions | Out-Null
        $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction Ignore)
    }
    foreach ($file in $files) {
        try { . $file.FullName } catch { Write-Warning "$($file.Name): $_" }
    }
    $null = Get-TsPreview
    Register-BinCommands (Join-Path $global:ProfileDir 'bin')
}
# Until then these names forward to the real functions on first use
foreach ($n in 'help', 'my', 'h', 'jump', 'srv', 'work', 'theme', 'lang', 'new', 'nav', 'pv', 'rgi', 'pk', 'gbr', 'o', 'kctx', 'kns', 'doctor', 'update', 'ex', 'bak', 'psg', 'cb', 'ep', 'Invoke-HelpPicker', 'Update-Completions', 'Get-TsPreview') {
    Set-Item "Function:global:$n" -Value ([scriptblock]::Create("Complete-Termistry; & '$n' @args"))
}

$customFile = Join-Path $ProfileDir 'custom.ps1'
$global:CustomFunctions = @()
if (Test-Path $customFile) {
    try {
        . $customFile
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($customFile, [ref]$null, [ref]$null)
        $global:CustomFunctions = @($ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object Name)
    } catch { Write-Warning "custom.ps1: $_" }
}
Remove-Variable customFile

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
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'CheatSheet' -ScriptBlock { Complete-Termistry; Invoke-HelpPicker }

    if ($Termistry.Abbreviations) {
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
    if ($Termistry.Predictions -gt 0 -and (Test-Path $predictorSrc)) {
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
                    $predictorKind, [DeepHistoryPredictor]::new((Get-PSReadLineOption).HistorySavePath, [Math]::Min(50, $Termistry.Predictions)))
            }
            Set-PSReadLineOption -PredictionSource Plugin
        } catch {
            Write-Warning "DeepHistoryPredictor: $_"
        }
    }
}

[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $ProfileDir 'prompt.ps1')
# ExtraPromptLineCount: the prompt is 3 lines (blank, path, arrow), InvokePrompt must redraw all of them in place
if ($isInteractive) { Set-PSReadLineOption -ContinuationPrompt '❯❯ ' -ExtraPromptLineCount 2 }

# Enter: layout fix + abbreviation, then run
if ($isInteractive) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'TermistryEnter' -ScriptBlock {
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($Termistry.LayoutFix -and $line) {
            $fixed = Repair-CommandLayout $line
            if ($fixed) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $fixed); $line = $fixed; $cursor = $fixed.Length }
        }
        if ($Termistry.Abbreviations) {
            $exp = Expand-Abbreviation $line $cursor
            if ($exp) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($exp.Start, $exp.Length, $exp.Text) }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_CTRL_R_OPTS = '--height=14'
$env:FZF_CTRL_T_OPTS = "--height=70% --preview=`"$cacheDir\preview.cmd {}`" --preview-window=right:55%"
# bat and delta page through less; the busybox less.exe some winget packages put on PATH does not know their flags
if (-not $env:BAT_PAGER) {
    $gitLess = Join-Path $env:ProgramFiles 'Git\usr\bin\less.exe'
    if ([IO.File]::Exists($gitLess)) { $env:BAT_PAGER = "`"$gitLess`" -RF" }
}

if ($isInteractive -and (Find-TkCommand fzf)) {
    # PSFzf auto-loads on first use; importing it eagerly costs ~0.3 s at startup
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'FolderNavigator' -ScriptBlock { Complete-Termistry; nav; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
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
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -SupportEvent -Action { Complete-Termistry }
} else {
    Complete-Termistry
}
