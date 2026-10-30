# Core: loaded before the first prompt. Everything the user types lives in toolkit-lazy.ps1,
# which Complete-TerminalSetup loads once the prompt is on screen.
function _tkRgb([int]$hex) { $PSStyle.Foreground.FromRgb($hex) }
function _tkBg([int]$hex) { $PSStyle.Background.FromRgb($hex) }

function Set-TerminalPalette {
    $p = $global:Palette
    $fg = @{}
    foreach ($k in 'mauve', 'blue', 'text', 'overlay0', 'overlay1', 'green', 'yellow', 'red', 'peach', 'teal', 'lavender', 'sky', 'flamingo') { $fg[$k] = $PSStyle.Foreground.FromRgb($p[$k]) }
    $global:TK = @{
        R = $PSStyle.Reset; B = $PSStyle.Bold; I = $PSStyle.Italic
        title = $fg.mauve; cmd = $fg.blue; text = $fg.text; dim = $fg.overlay0
        ok = $fg.green; warn = $fg.yellow; err = $fg.red; accent = $fg.peach; teal = $fg.teal; lavender = $fg.lavender
    }

    $PSStyle.FileInfo.Directory    = $fg.blue
    $PSStyle.FileInfo.SymbolicLink = $fg.teal
    $PSStyle.FileInfo.Executable   = $fg.green
    foreach ($ext in '.zip', '.7z', '.rar', '.tar', '.gz') { $PSStyle.FileInfo.Extension[$ext] = $fg.peach }
    foreach ($ext in '.ps1', '.psm1', '.sh', '.py', '.js', '.ts') { $PSStyle.FileInfo.Extension[$ext] = $fg.green }
    $PSStyle.Formatting.TableHeader  = $fg.mauve + $PSStyle.Bold
    $PSStyle.Formatting.FormatAccent = $fg.mauve
    $PSStyle.Formatting.Error        = $fg.red
    $PSStyle.Formatting.ErrorAccent  = $fg.peach
    $PSStyle.Formatting.Warning      = $fg.yellow
    $PSStyle.Formatting.Verbose      = $fg.overlay1
    $PSStyle.Formatting.Debug        = $fg.overlay1
    $PSStyle.Progress.Style          = $fg.mauve

    $hex = { param($c) '#{0:x6}' -f $c }
    $env:FZF_DEFAULT_OPTS = @(
        '--height=45% --layout=reverse --border=rounded --info=inline-right'
        '--prompt="❯ " --pointer="▌" --marker="●"'
        "--color=bg:-1,bg+:$(& $hex $p.surface0),fg:$(& $hex $p.text),fg+:$(& $hex $p.text),hl:$(& $hex $p.red),hl+:$(& $hex $p.red)"
        "--color=border:$(& $hex $p.surface2),header:$(& $hex $p.red),info:$(& $hex $p.overlay1),prompt:$(& $hex $p.mauve)"
        "--color=pointer:$(& $hex $p.rosewater),marker:$(& $hex $p.lavender),spinner:$(& $hex $p.rosewater),selected-bg:$(& $hex $p.surface1)"
    ) -join ' '

    if ($global:isInteractive -and (Get-Module PSReadLine)) {
        Set-PSReadLineOption -Colors @{
            Default                = $fg.text
            Command                = $fg.blue
            Parameter              = $fg.teal
            Operator               = $fg.sky
            Variable               = $fg.flamingo
            String                 = $fg.green
            Number                 = $fg.peach
            Type                   = $fg.yellow
            Member                 = $fg.lavender
            Keyword                = $fg.mauve
            Comment                = $fg.overlay0 + $PSStyle.Italic
            Error                  = $fg.red
            Emphasis               = $fg.yellow
            Selection              = $PSStyle.Background.FromRgb($p.surface1)
            ContinuationPrompt     = $fg.overlay0
            InlinePrediction       = $fg.overlay0
            ListPrediction         = $fg.mauve
            ListPredictionSelected = $PSStyle.Background.FromRgb($p.surface0)
            ListPredictionTooltip  = $fg.overlay1
        }
    }
}

function Write-TkRow([string]$Command, [string]$Description, [string]$Example) {
    $cmdCell = if ($Command.Length -ge 26) { $Command + '  ' } else { $Command.PadRight(26) }
    $line = '    ' + $TK.cmd + $cmdCell + $TK.R + $TK.text + $Description + $TK.R
    if ($Example) { $line += '  ' + $TK.dim + $Example + $TK.R }
    Write-Host $line
}

function Write-TkTitle([string]$Title, [string]$Hint) {
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}{6}" -f $TK.title, $TK.B, $Title, $TK.R, $TK.dim, $Hint, $TK.R)
}

function Write-TkTable($Rows, $Columns) {
    $widths = foreach ($col in $Columns) {
        $max = $col.N.Length
        foreach ($r in $Rows) { $len = "$($r.($col.P))".Length; if ($len -gt $max) { $max = $len } }
        $max
    }
    $head = for ($i = 0; $i -lt $Columns.Count; $i++) { $Columns[$i].N.PadRight($widths[$i]) }
    if (($head -join '').Trim()) { Write-Host ('  ' + $TK.dim + ($head -join '   ') + $TK.R) }
    foreach ($r in $Rows) {
        $cells = for ($i = 0; $i -lt $Columns.Count; $i++) {
            $col = $Columns[$i]
            $color = if ($col.C -is [scriptblock]) { $TK[(& $col.C $r)] } else { $TK[$col.C] }
            $color + "$($r.($col.P))".PadRight($widths[$i]) + $TK.R
        }
        Write-Host ('  ' + ($cells -join '   '))
    }
}

function Get-TkBar([double]$Percent, [int]$Width = 20) {
    $filled = [math]::Round([math]::Min(100, [math]::Max(0, $Percent)) / 100 * $Width)
    $color = if ($Percent -ge 90) { $TK.err } elseif ($Percent -ge 70) { $TK.warn } else { $TK.ok }
    $color + ('█' * $filled) + $TK.dim + ('░' * ($Width - $filled)) + $TK.R + (' {0,3:N0}%' -f $Percent)
}

# ── abbreviations (fish-style: expand on space/Enter at command position) ────
$global:Abbreviations = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)

function abbr {
    param([string]$Name, [string]$Expansion, [switch]$Remove)
    $custom = Join-Path $global:ProfileDir 'custom.ps1'
    if ($Remove) {
        [void]$global:Abbreviations.Remove($Name)
        if (Test-Path $custom) {
            $kept = Get-Content $custom | Where-Object { $_ -notmatch "^\s*abbr\s+(['`"]?)$([regex]::Escape($Name))\1\s" }
            [IO.File]::WriteAllLines($custom, [string[]]$kept, [Text.UTF8Encoding]::new($false))
        }
        return
    }
    if (-not $Name) {
        Complete-TerminalSetup
        Write-TkTitle $TkStr.abbr_title $TkStr.abbr_hint
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
        Write-Host ''
        return
    }
    if (-not $Expansion) { Complete-TerminalSetup; Write-Host "  $($TK.err)$($TkStr.abbr_usage)$($TK.R)"; return }
    $global:Abbreviations[$Name] = $Expansion
    # typed interactively (not sourced from a file): persist to custom.ps1
    if ($MyInvocation.ScriptName -eq '' -and $global:isInteractive) {
        $line = "abbr $Name '$($Expansion.Replace("'", "''"))'"
        if (-not (Test-Path $custom) -or -not (Select-String -Path $custom -SimpleMatch $line -Quiet)) {
            Add-Content $custom "`n$line" -Encoding utf8
            Complete-TerminalSetup
            Write-Host ("  {0}{1}{2}" -f $TK.dim, ($TkStr.abbr_saved -f $line), $TK.R)
        }
    }
}

# Returns @{Start; Length; Text; Cursor} when the word before the cursor is an abbreviation
# in command position (line start or after | ; & ( {). '%' in the expansion marks the cursor.
function Expand-Abbreviation([string]$Line, [int]$Cursor) {
    if (-not $global:Abbreviations.Count -or $Cursor -le 0) { return }
    $before = $Line.Substring(0, $Cursor)
    if ($before -notmatch '(?:^|[|;&({])\s*(\S+)$') { return }
    $word = $Matches[1]
    if (-not $global:Abbreviations.ContainsKey($word)) { return }
    $text = $global:Abbreviations[$word]
    $marker = $text.IndexOf('%')
    if ($marker -ge 0) { $text = $text.Remove($marker, 1) }
    $start = $Cursor - $word.Length
    @{ Start = $start; Length = $word.Length; Text = $text; Cursor = $(if ($marker -ge 0) { $start + $marker } else { -1 }) }
}

foreach ($pair in @{ g = 'git'; k = 'kubectl'; d = 'docker'; dc = 'docker compose'; gco = 'git checkout'; gp = 'git push'; gl = 'git pull'; gcm = 'git commit -m "%"'; kgp = 'kubectl get pods'; kga = 'kubectl get all' }.GetEnumerator()) {
    $global:Abbreviations[$pair.Key] = $pair.Value
}

# ── keyboard layout: a command typed in the Russian layout becomes its Latin counterpart ──
$TkLayoutMap = @{}
$ru = 'ёйцукенгшщзхъфывапролджэячсмитьбюЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ'
$en = '`qwertyuiop[]asdfghjkl;''zxcvbnm,.~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>'
for ($i = 0; $i -lt $ru.Length; $i++) { $TkLayoutMap[$ru[$i]] = $en[$i] }
Remove-Variable ru, en, i

function Convert-Layout([string]$Text) {
    $sb = [Text.StringBuilder]::new($Text.Length)
    foreach ($ch in $Text.ToCharArray()) { [void]$sb.Append($(if ($TkLayoutMap.ContainsKey($ch)) { $TkLayoutMap[$ch] } else { $ch })) }
    $sb.ToString()
}

# Only when the first word is Cyrillic, is not a real command, and converts to a known one
function Repair-CommandLayout([string]$Line) {
    if ($Line -notmatch '^\s*[А-Яа-яЁё]') { return }
    $first = ($Line.Trim() -split '\s+', 2)[0]
    if (Get-Command $first -ErrorAction Ignore) { return }
    $fixed = Convert-Layout $first
    if ($fixed -eq $first) { return }
    if (-not (Get-Command $fixed -ErrorAction Ignore) -and -not $global:Abbreviations.ContainsKey($fixed)) { return }
    Convert-Layout $Line
}

# ── bin\: every script becomes a command, runner chosen by extension ─────────
$global:ScriptRunners = [ordered]@{
    '.ps1' = @('pwsh -NoProfile -File')
    '.py'  = @('uv run', 'python')
    '.js'  = @('node')
    '.ts'  = @('bun', 'deno run -A', 'node')
    '.sh'  = @('bash')
    '.go'  = @('go run')
    '.rs'  = @('rust-script')
    '.clj' = @('bb')
    '.rb'  = @('ruby')
    '.lua' = @('lua')
    '.php' = @('php')
}

function Get-ScriptRunner([string]$Extension) {
    foreach ($candidate in $global:ScriptRunners[$Extension]) {
        if (Get-Command ($candidate -split ' ')[0] -ErrorAction Ignore) { return $candidate }
    }
}

function Register-BinCommands([string]$Dir) {
    $global:UserCommands = @()
    if (-not (Test-Path $Dir)) { return }
    # last on PATH: a file in bin never hides a real program of the same name
    if (($env:PATH -split ';') -notcontains $Dir) { $env:PATH = "$env:PATH;$Dir" }
    foreach ($f in Get-ChildItem $Dir -File | Sort-Object Name) {
        $name = $f.BaseName
        $ext = $f.Extension.ToLower()
        if (-not $global:ScriptRunners.Contains($ext) -or $name -notmatch '^[A-Za-z_][\w-]*$') { continue }
        # never shadow a real command; bin itself is on PATH, so ignore matches from there
        $taken = Get-Command $name -All -ErrorAction Ignore |
            Where-Object { $_.Source -notlike "$Dir\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
        if ($taken) { continue }
        $help = (Get-Content $f.FullName -First 15 | Select-String -Pattern '^\s*(#|//|;;|--)\s*help:\s*(.+)$' | Select-Object -First 1)
        $help = if ($help) { $help.Matches[0].Groups[2].Value.Trim() } else { '' }
        $runner = Get-ScriptRunner $ext
        $body = if ($runner) {
            $parts = ($runner -split ' ') | ForEach-Object { "'$_'" }
            "# UserCommand`n& $($parts -join ' ') '$($f.FullName)' @args"
        } else {
            "# UserCommand`nComplete-TerminalSetup; Write-Host ('  ' + (`$TkStr.bin_norunner -f '$($f.Name)', '$($global:ScriptRunners[$ext] -join ' / ')'))"
        }
        Set-Item "Function:global:$name" -Value ([scriptblock]::Create($body))
        $global:UserCommands += [pscustomobject]@{ Name = $name; File = $f.Name; Help = $help; Runner = $(if ($runner) { $runner } else { '- ' + ($global:ScriptRunners[$ext] -join '/') }); Path = $f.FullName }
    }
}
