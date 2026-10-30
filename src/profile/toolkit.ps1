function _tkRgb([int]$hex) { $PSStyle.Foreground.FromRgb($hex) }
function _tkBg([int]$hex) { $PSStyle.Background.FromRgb($hex) }

function Set-TerminalPalette {
    $p = $global:Palette
    $global:TK = @{
        R = $PSStyle.Reset; B = $PSStyle.Bold; I = $PSStyle.Italic
        title = _tkRgb $p.mauve; cmd = _tkRgb $p.blue; text = _tkRgb $p.text; dim = _tkRgb $p.overlay0
        ok = _tkRgb $p.green; warn = _tkRgb $p.yellow; err = _tkRgb $p.red; accent = _tkRgb $p.peach
        teal = _tkRgb $p.teal; lavender = _tkRgb $p.lavender
    }

    $PSStyle.FileInfo.Directory    = _tkRgb $p.blue
    $PSStyle.FileInfo.SymbolicLink = _tkRgb $p.teal
    $PSStyle.FileInfo.Executable   = _tkRgb $p.green
    foreach ($ext in '.zip', '.7z', '.rar', '.tar', '.gz') { $PSStyle.FileInfo.Extension[$ext] = _tkRgb $p.peach }
    foreach ($ext in '.ps1', '.psm1', '.sh', '.py', '.js', '.ts') { $PSStyle.FileInfo.Extension[$ext] = _tkRgb $p.green }
    $PSStyle.Formatting.TableHeader  = (_tkRgb $p.mauve) + $PSStyle.Bold
    $PSStyle.Formatting.FormatAccent = _tkRgb $p.mauve
    $PSStyle.Formatting.Error        = _tkRgb $p.red
    $PSStyle.Formatting.ErrorAccent  = _tkRgb $p.peach
    $PSStyle.Formatting.Warning      = _tkRgb $p.yellow
    $PSStyle.Formatting.Verbose      = _tkRgb $p.overlay1
    $PSStyle.Formatting.Debug        = _tkRgb $p.overlay1
    $PSStyle.Progress.Style          = _tkRgb $p.mauve

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
            Default                = _tkRgb $p.text
            Command                = _tkRgb $p.blue
            Parameter              = _tkRgb $p.teal
            Operator               = _tkRgb $p.sky
            Variable               = _tkRgb $p.flamingo
            String                 = _tkRgb $p.green
            Number                 = _tkRgb $p.peach
            Type                   = _tkRgb $p.yellow
            Member                 = _tkRgb $p.lavender
            Keyword                = _tkRgb $p.mauve
            Comment                = (_tkRgb $p.overlay0) + $PSStyle.Italic
            Error                  = _tkRgb $p.red
            Emphasis               = _tkRgb $p.yellow
            Selection              = _tkBg $p.surface1
            ContinuationPrompt     = _tkRgb $p.overlay0
            InlinePrediction       = _tkRgb $p.overlay0
            ListPrediction         = _tkRgb $p.mauve
            ListPredictionSelected = _tkBg $p.surface0
            ListPredictionTooltip  = _tkRgb $p.overlay1
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
    Write-Host ('  ' + $TK.dim + ($head -join '   ') + $TK.R)
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

function Format-TkSize([double]$Bytes) {
    foreach ($u in $T.units) { if ($Bytes -lt 1024) { return ('{0:N1} {1}' -f $Bytes, $u) -replace '[.,]0 ', ' ' }; $Bytes /= 1024 }
    '{0:N1} {1}' -f $Bytes, $T.units[-1]
}

# docker/kubectl can hang for a long time when their daemon is down
function Invoke-WithTimeout([string]$Command, [string[]]$Arguments, [int]$Milliseconds = 3000) {
    $exe = (Get-Command $Command -ErrorAction SilentlyContinue).Source
    if (-not $exe) { return $null }
    $psi = [Diagnostics.ProcessStartInfo]::new($exe)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEndAsync()
    if (-not $proc.WaitForExit($Milliseconds)) { try { $proc.Kill() } catch {}; return $null }
    if ($proc.ExitCode -ne 0) { return $null }
    $out.Result -split "`n" | Where-Object { $_.Trim() }
}

# ── help ─────────────────────────────────────────────────────────────────────
function Get-TkUserSection {
    $rows = @()
    foreach ($c in $global:UserCommands) { $rows += , ($c.Name, $c.Help, ("bin\" + $c.File)) }
    foreach ($f in $global:CustomFunctions) { $rows += , ($f, $T.help_custom) }
    if ($global:Abbreviations.Count) {
        $list = ($global:Abbreviations.GetEnumerator() | Select-Object -First 6 | ForEach-Object { "$($_.Key)→$($_.Value)" }) -join '  '
        if ($global:Abbreviations.Count -gt 6) { $list += '  ' + ($T.help_more -f ($global:Abbreviations.Count - 6)) }
        $rows += , ('abbr', $list, $T.help_abbr_all)
    }
    if ($rows) { @{ Key = 'my'; Title = $T.help_user; Rows = $rows } }
}

function Get-TkAllSections { @($T.sections) + @(Get-TkUserSection) }

function Show-TkHelp($Sections) {
    if (-not $Sections) { $Sections = Get-TkAllSections }
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}: {6}{7}" -f $TK.title, $TK.B, $T.help_title, $TK.R, $TK.dim, $T.help_theme, $global:ThemeName, $TK.R)
    Write-Host ("  {0}{1}{2}" -f $TK.dim, $T.help_hint, $TK.R)
    foreach ($s in $Sections) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}{3}  {4}help {5}{6}" -f $TK.title, $TK.B, $s.Title, $TK.R, $TK.dim, $s.Key, $TK.R)
        foreach ($r in $s.Rows) { Write-TkRow @r }
    }
    Write-Host ''
}

function help {
    if (-not $args) { Show-TkHelp; return }
    $query = "$args"
    $all = Get-TkAllSections
    $section = $all | Where-Object { $_.Key -eq $query -or $_.Title -eq $query }
    if ($section) { Show-TkHelp $section; return }

    $hits = @(foreach ($s in $all) {
        foreach ($r in $s.Rows) { if (($r -join ' ').IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) { , $r } }
    })
    $isCmdlet = Get-Command $query -CommandType Cmdlet, Alias -ErrorAction SilentlyContinue
    if ($hits -and $args.Count -eq 1 -and -not $isCmdlet) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}: {3}{4}" -f $TK.title, $TK.B, $T.help_found, $query, $TK.R)
        foreach ($r in $hits) { Write-TkRow @r }
        Write-Host ''
        return
    }
    Get-Help @args
}

function Invoke-HelpPicker {
    $lines = foreach ($s in Get-TkAllSections) {
        foreach ($r in $s.Rows) {
            $cmd = $r[0]; $desc = $r[1]
            $shown = '{0,-28} {1}' -f $cmd, $desc
            if ($r.Count -gt 2 -and $r[2]) { $shown += "   $($r[2])" }
            $insert = if ($cmd -match $T.no_insert) { '' } else { ($cmd -split ' / | · | \[| <')[0].Trim() }
            "{0,-12}  {1}`t{2}" -f $s.Title, $shown, $insert
        }
    }
    $pick = $lines | fzf --height=60% --prompt='help ❯ ' --header=$T.picker_header --delimiter="`t" --with-nth=1 --tabstop=4
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($pick) {
        $insert = ($pick -split "`t")[1]
        if ($insert) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($insert) }
    }
}

# ── ssh ──────────────────────────────────────────────────────────────────────
function Get-SshHost {
    $config = Join-Path $HOME '.ssh\config'
    if (-not (Test-Path $config)) { return }
    $hosts = [ordered]@{}
    $current = @()
    foreach ($raw in Get-Content $config) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $key, $value = $line -split '\s*=\s*|\s+', 2
        $field = @{ hostname = 'HostName'; user = 'User'; port = 'Port'; identityfile = 'IdentityFile' }[$key.ToLower()]
        if ($key -eq 'Host') {
            $current = foreach ($name in $value -split '\s+') {
                if ($name -match '[*?!]') { continue }
                if ($hosts.Contains($name)) { $hosts[$name].Duplicate = $true }
                else { $hosts[$name] = [pscustomobject]@{ Name = $name; HostName = ''; User = ''; Port = ''; IdentityFile = ''; Duplicate = $false } }
                $hosts[$name]
            }
        } elseif ($key -eq 'Match') {
            $current = @()
        } elseif ($field) {
            # ssh semantics: the first value wins
            foreach ($h in $current) { if (-not $h.$field) { $h.$field = $value } }
        }
    }
    foreach ($h in $hosts.Values) {
        if (-not $h.HostName) { $h.HostName = $h.Name }
        if (-not $h.Port) { $h.Port = '22' }
        if ($h.IdentityFile) { $h.IdentityFile = Split-Path $h.IdentityFile -Leaf }
        $h
    }
}

function Select-SshHost([string]$Query, [string]$Header) {
    $hosts = @(Get-SshHost)
    if (-not $hosts) { Write-Host "  $($T.ssh_empty)"; return }
    $width = ($hosts.Name | Measure-Object Length -Maximum).Maximum
    $pick = $hosts | ForEach-Object { '{0}  {1}@{2}' -f $_.Name.PadRight($width), $_.User, $_.HostName } |
        fzf --query=$Query --select-1 --height=14 --header=$Header
    if ($pick) { ($pick -split '\s+')[0] }
}

function jump([string]$Query) {
    $name = Select-SshHost $Query $T.jump_header
    if ($name) {
        Write-Host ("  {0}→ ssh {1}{2}" -f $TK.dim, $name, $TK.R)
        ssh $name
    }
}

Register-ArgumentCompleter -Native -CommandName ssh, scp, sftp -ScriptBlock {
    param($wordToComplete, $commandAst)
    $suffix = if ($commandAst.CommandElements[0].Value -eq 'ssh') { '' } else { ':' }
    Get-SshHost | Where-Object Name -like "$wordToComplete*" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.Name + $suffix, $_.Name, 'ParameterValue', "$($_.User)@$($_.HostName)")
    }
}

# ── srv ──────────────────────────────────────────────────────────────────────
function srv {
    param(
        [Parameter(Position = 0)][ValidateSet('install', 'remove', 'help')][string]$Action = 'help',
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [ArgumentCompleter({ param($c, $p, $word) (Get-SshHost).Name | Where-Object { $_ -like "$word*" } })]
        [string[]]$Hosts,
        [string]$Env,
        [ValidateSet('', 'ru', 'en')][string]$Lang = ''
    )
    $dir = Join-Path $global:ProfileDir 'server'
    if ($Action -eq 'help') { Show-SrvHelp $dir; return }
    foreach ($f in 'bashrc.local', 'inputrc', 'install.sh') {
        if (-not (Test-Path (Join-Path $dir $f))) { Write-Host "  $($TK.err)$($T.srv_missing -f "$dir\$f")$($TK.R)"; return }
    }
    if ($Env -and $Env -notmatch '^[A-Za-z0-9_-]{1,20}$') { Write-Host "  $($TK.err)$($T.srv_env)$($TK.R)"; return }
    if (-not $Hosts) {
        $picked = Select-SshHost '' ($T.srv_pick -f $Action)
        if (-not $picked) { return }
        $Hosts = @($picked)
    }
    if (-not $Lang) { $Lang = $global:LangName }

    $read = { param($path) [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }
    $b64 = { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
    $custom = foreach ($f in Get-ChildItem (Join-Path $dir 'custom') -File -Filter *.sh -ErrorAction SilentlyContinue) {
        "__put '.bashrc.d/$($f.Name)' '$(& $b64 (& $read $f.FullName))'"
    }
    $script = (& $read (Join-Path $dir 'install.sh')).Replace('__ACTION__', $Action).Replace('__ENV__', $Env).Replace('__LANG__', $Lang)
    $script = $script.Replace('__BASHRC_B64__', (& $b64 (& $read (Join-Path $dir 'bashrc.local'))))
    $script = $script.Replace('__INPUTRC_B64__', (& $b64 (& $read (Join-Path $dir 'inputrc'))))
    $script = $script.Replace('__CUSTOM_FILES__', ($custom -join "`n"))
    # the trailing newline PowerShell adds on pipe lands inside the final "# end" comment
    $script = $script.TrimEnd()

    foreach ($h in $Hosts) {
        Write-TkTitle "srv $Action → $h" ''
        $script | ssh $h 'bash -s'
        if ($LASTEXITCODE -eq 0 -and $Action -eq 'remove') { Write-Host "  $($TK.ok)$($T.srv_removed)$($TK.R) $($TK.dim)$($T.srv_restore -f $h)$($TK.R)" }
        elseif ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)$($T.srv_done)$($TK.R) $($TK.dim)$($T.srv_relogin -f $h)$($TK.R)" }
        else { Write-Host "  $($TK.err)$($T.srv_error -f $LASTEXITCODE)$($TK.R)" }
        Write-Host ''
    }
}

function Show-SrvHelp([string]$Dir) {
    Write-TkTitle $T.srv_title ($T.srv_templates -f $Dir)
    foreach ($r in $T.srv_rows) { Write-TkRow @r }
    Write-Host ''
    Write-Host "  $($TK.title)$($T.srv_gets)$($TK.R)"
    foreach ($line in $T.srv_gets_rows) { Write-Host "    $line" }
    Write-Host ''
    Write-Host "  $($TK.title)$($T.srv_custom)$($TK.R)"
    foreach ($line in $T.srv_custom_rows) { Write-Host "    $($line -f $Dir)" }
    Write-Host ''
    Write-Host "  $($TK.dim)$($T.srv_note)$($TK.R)"
    Write-Host ''
}

# ── my ───────────────────────────────────────────────────────────────────────
function my {
    param(
        [Parameter(Position = 0)][ArgumentCompleter({
            param($c, $p, $word) $T.my_topics.get_Keys() | Where-Object { $_ -like "$word*" }
        })][string]$Topic,
        [Parameter(Position = 1)][string]$Filter
    )
    switch ($Topic) {
        'sys'    { Show-MySys }
        'ssh'    { Show-MySsh $Filter }
        'ports'  { Show-MyPorts $Filter }
        'ip'     { Show-MyIp $Filter }
        'k8s'    { Show-MyK8s }
        'docker' { Show-MyDocker }
        'tools'  { Show-MyTools }
        'path'   { Show-MyPath }
        'git'    { Show-MyGit }
        'cmds'   { Show-MyCommands }
        'keys'   { Show-TkHelp ($T.sections | Where-Object { $_.Key -in 'keys', 'input' }) }
        default {
            Write-TkTitle $T.my_title $T.my_hint
            # get_Keys(): the dictionary has a 'keys' entry, so .Keys would return it
            foreach ($k in $T.my_topics.get_Keys()) { Write-TkRow "my $k" $T.my_topics[$k] }
            Write-Host ''
        }
    }
}

function Show-MySys {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    Write-TkTitle $env:COMPUTERNAME (($T.sys_uptime -f [int]$up.TotalDays, $up.Hours, $up.Minutes) + ' · ' + $os.Caption.Replace('Microsoft ', ''))
    $cpuName = ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)|CPU|Processor', '').Trim()
    $row = { param($label, $percent, $note) Write-Host ("  {0}{1}{2}  {3}  {4}{5}{6}" -f $TK.dim, $label.PadRight(10), $TK.R, (Get-TkBar $percent), $TK.dim, $note, $TK.R) }
    & $row $T.sys_cpu $cpu.LoadPercentage "$cpuName · $($T.sys_cores): $([Environment]::ProcessorCount)"
    $memUsed = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
    $memTotal = $os.TotalVisibleMemorySize * 1KB
    & $row $T.sys_mem ($memUsed / $memTotal * 100) "$(Format-TkSize $memUsed) $($T.of) $(Format-TkSize $memTotal)"
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object DeviceID) {
        if (-not $d.Size) { continue }
        $used = $d.Size - $d.FreeSpace
        & $row "$($T.sys_disk) $($d.DeviceID)" ($used / $d.Size * 100) "$(Format-TkSize $used) $($T.of) $(Format-TkSize $d.Size)$(if ($d.VolumeName) { " · $($d.VolumeName)" })"
    }

    Write-Host ''
    Write-Host ("  {0}{1}{2}" -f $TK.title, $T.sys_bymem, $TK.R)
    $top = Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Memory = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum; Count = $_.Count }
    } | Sort-Object Memory -Descending | Select-Object -First 6
    foreach ($t in $top) {
        Write-Host ("  {0}{1,-26}{2} {3,9}{4}{5}" -f $TK.cmd, $t.Name, $TK.R, (Format-TkSize $t.Memory), $TK.dim, $(if ($t.Count -gt 1) { "  ×$($t.Count)" }), $TK.R)
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $T.sys_containers, $TK.R)
        $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}')
        if ($null -eq $rows) { Write-Host "  $($TK.dim)$($T.docker_down)$($TK.R)" }
        elseif (-not $rows) { Write-Host "  $($TK.dim)$($T.docker_none)$($TK.R)" }
        foreach ($r in $rows) {
            $name, $state = $r -split "`t"
            $dot = if ($state -match 'unhealthy|Restarting') { $TK.err } elseif ($state -like 'Up*') { $TK.ok } elseif ($state -like 'Exited (0)*') { $TK.dim } else { $TK.err }
            Write-Host ("  {0}●{1} {2,-30} {3}{4}{5}" -f $dot, $TK.R, $name, $TK.dim, $state, $TK.R)
        }
    }
    Write-Host ''
}

function Show-MyK8s {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)$($T.k8s_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout kubectl @('config', 'get-contexts', '--no-headers') 5000
    Write-TkTitle 'Kubernetes' $T.k8s_hint
    if (-not $rows) { Write-Host "  $($TK.dim)$($T.k8s_none)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $f = $r -split '\s+'
        $cur = $f[0] -eq '*'
        if ($cur) { $f = $f[1..($f.Count - 1)] }
        [pscustomobject]@{ Mark = $(if ($cur) { '●' } else { ' ' }); Name = $f[0]; Cluster = $f[1]; Namespace = $(if ($f.Count -gt 3) { $f[3] } else { 'default' }) }
    }
    Write-TkTable $list @(
        @{ N = ' '; P = 'Mark'; C = 'ok' }
        @{ N = $T.col_context; P = 'Name'; C = { param($r) if ($r.Mark -eq '●') { 'cmd' } else { 'text' } } }
        @{ N = $T.col_cluster; P = 'Cluster'; C = 'dim' }
        @{ N = 'Namespace'; P = 'Namespace'; C = 'accent' }
    )
    Write-Host ''
}

function Show-MyDocker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)$($T.docker_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}\t{{.Ports}}')
    Write-TkTitle 'Docker' $T.docker_hint
    if ($null -eq $rows) { Write-Host "  $($TK.dim)$($T.docker_down)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $name, $state, $ports = $r -split "`t"
        $ports = ($ports -replace '0\.0\.0\.0:|\[::\]:|/tcp', '' -split ', ' | Sort-Object -Unique) -join ' '
        [pscustomobject]@{ Dot = '●'; Name = $name; State = $state; Ports = $ports }
    }
    if (-not $list) { Write-Host "  $($TK.dim)$($T.docker_none)$($TK.R)" }
    else {
        Write-TkTable $list @(
            @{ N = ' '; P = 'Dot'; C = { param($r) if ($r.State -match 'unhealthy|Restarting') { 'err' } elseif ($r.State -like 'Up*') { 'ok' } elseif ($r.State -like 'Exited (0)*') { 'dim' } else { 'err' } } }
            @{ N = $T.col_container; P = 'Name'; C = 'cmd' }
            @{ N = $T.col_status; P = 'State'; C = 'dim' }
            @{ N = $T.col_ports; P = 'Ports'; C = 'accent' }
        )
    }
    $projects = Invoke-WithTimeout docker @('compose', 'ls', '-a', '--format', '{{.Name}}\t{{.Status}}\t{{.ConfigFiles}}') 5000
    if ($projects) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $T.docker_projects, $TK.R)
        foreach ($p in $projects) {
            $name, $state, $files = $p -split "`t"
            Write-Host ("  {0}{1,-20}{2} {3,-24} {4}{5}{6}" -f $TK.cmd, $name, $TK.R, $state, $TK.dim, (Split-Path ($files -split ',')[0]), $TK.R)
        }
    }
    Write-Host ''
}

function Show-MySsh([string]$Filter) {
    $hosts = @(Get-SshHost | Where-Object { -not $Filter -or "$($_.Name) $($_.HostName) $($_.User)" -like "*$Filter*" })
    Write-TkTitle $T.ssh_title $T.ssh_hint
    if (-not $hosts) { Write-Host "  $($TK.dim)$($T.nothing_found)$($TK.R)"; Write-Host ''; return }
    Write-TkTable $hosts @(
        @{ N = $T.col_name; P = 'Name'; C = 'cmd' }
        @{ N = $T.col_address; P = 'HostName'; C = 'text' }
        @{ N = $T.col_user; P = 'User'; C = { param($r) if ($r.User -eq 'root') { 'err' } else { 'ok' } } }
        @{ N = $T.col_port; P = 'Port'; C = 'dim' }
        @{ N = $T.col_key; P = 'IdentityFile'; C = 'dim' }
    )
    foreach ($d in $hosts | Where-Object Duplicate) { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($T.ssh_dup -f $d.Name, $d.User), $TK.R) }
    Write-Host ''
}

function Show-MyIp([string]$Mode) {
    $rows = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Sort-Object InterfaceMetric |
        ForEach-Object { [pscustomobject]@{ Interface = $_.InterfaceAlias; Address = "$($_.IPAddress)/$($_.PrefixLength)" } }
    Write-TkTitle $T.ip_title $T.ip_hint
    Write-TkTable $rows @(@{ N = $T.col_iface; P = 'Interface'; C = 'text' }, @{ N = $T.col_address; P = 'Address'; C = 'cmd' })
    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    if ($gw) { Write-Host ("  {0}{1}{2}  {3} {4}({5}){6}" -f $TK.dim, $T.ip_gateway, $TK.R, $gw.NextHop, $TK.dim, $gw.InterfaceAlias, $TK.R) }
    if ($Mode -eq 'public') {
        try { $ip = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5; Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.dim, $T.ip_public, $TK.R, $TK.accent, $ip, $TK.R) }
        catch { Write-Host "  $($TK.err)$($T.ip_public_fail)$($TK.R)" }
    }
    Write-Host ''
}

function Show-MyPorts([string]$Filter) {
    $names = @{}; Get-Process | ForEach-Object { $names[$_.Id] = $_.ProcessName }
    $all = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Group-Object LocalPort | ForEach-Object {
        $c = $_.Group[0]
        [pscustomobject]@{
            Port = [int]$c.LocalPort
            Address = ($_.Group.LocalAddress | Sort-Object -Unique) -join ', '
            Process = $names[[int]$c.OwningProcess]
            PID = $c.OwningProcess
        }
    } | Sort-Object Port
    $rows = if ($Filter -eq 'all') { $all }
            elseif ($Filter) { $all | Where-Object { "$($_.Port)" -eq $Filter -or $_.Process -like "*$Filter*" } }
            else { $all | Where-Object Port -lt 49152 }
    Write-TkTitle $T.ports_title $T.ports_hint
    Write-TkTable $rows @(
        @{ N = $T.col_port; P = 'Port'; C = 'accent' }
        @{ N = $T.col_process; P = 'Process'; C = 'cmd' }
        @{ N = 'PID'; P = 'PID'; C = 'dim' }
        @{ N = $T.col_address; P = 'Address'; C = 'dim' }
    )
    Write-Host ''
}

function Show-MyPath {
    $seen = @{}
    $rows = foreach ($p in $env:PATH -split ';' | Where-Object { $_ }) {
        $state = if ($seen.ContainsKey($p.TrimEnd('\'))) { $T.path_dup } elseif (-not (Test-Path $p)) { $T.path_missing } else { '' }
        $seen[$p.TrimEnd('\')] = $true
        [pscustomobject]@{ Path = $p; State = $state }
    }
    Write-TkTitle $T.path_title $T.path_hint
    Write-TkTable $rows @(
        @{ N = $T.col_folder; P = 'Path'; C = { param($r) if ($r.State) { 'dim' } else { 'text' } } }
        @{ N = ''; P = 'State'; C = { param($r) if ($r.State -eq $T.path_dup) { 'warn' } else { 'err' } } }
    )
    Write-Host ''
}

function Show-MyTools {
    $specs = [ordered]@{
        pwsh = '--version'; git = '--version'; gh = '--version'; lazygit = '--version'; node = '--version'; python = '--version'
        uv = '--version'; docker = '--version'; kubectl = 'version --client'; helm = 'version --short'; kind = 'version'
        minikube = 'version --short'; code = '--version'; 'oh-my-posh' = 'version'; fzf = '--version'; zoxide = '--version'
        eza = '--version'; bat = '--version'; rg = '--version'; fd = '--version'; delta = '--version'; tldr = '--version'
    }
    $rows = $specs.GetEnumerator() | ForEach-Object -ThrottleLimit 10 -Parallel {
        $name, $argLine = $_.Key, $_.Value
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { return }
        $out = (& $name ($argLine -split ' ') 2>&1 | Select-Object -First 3) -join ' '
        [pscustomobject]@{ Name = $name; Version = ([regex]::Match($out, '\d+\.\d+(\.\d+)?')).Value; Path = $cmd.Source }
    } | Sort-Object Name
    Write-TkTitle $T.tools_title $T.tools_hint
    Write-TkTable $rows @(
        @{ N = $T.col_program; P = 'Name'; C = 'cmd' }
        @{ N = $T.col_version; P = 'Version'; C = 'ok' }
        @{ N = $T.col_where; P = 'Path'; C = 'dim' }
    )
    Write-Host ''
}

function Show-MyGit {
    Write-TkTitle 'Git' ''
    Write-TkRow $T.git_name (git config --global user.name)
    Write-TkRow $T.git_email (git config --global user.email)
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) {
        Write-TkRow $T.git_repo $root
        Write-TkRow $T.git_branch (git branch --show-current)
        foreach ($r in git remote -v | Where-Object { $_ -like '*(fetch)' }) {
            $name, $url = $r -split '\s+'
            Write-TkRow "remote $name" $url
        }
    } else {
        Write-Host "    $($TK.dim)$($T.git_none)$($TK.R)"
    }
    $aliases = git config --global --get-regexp '^alias\.' 2>$null
    foreach ($a in $aliases) { $k, $v = $a -split ' ', 2; Write-TkRow ('git ' + $k.Substring(6)) $v }
    Write-Host ''
}

function Show-MyCommands {
    Write-TkTitle $T.cmds_title ($T.cmds_hint -f $global:ProfileDir)
    if ($global:UserCommands) {
        Write-Host ("  {0}bin\{1}" -f $TK.title, $TK.R)
        foreach ($c in $global:UserCommands) { Write-TkRow $c.Name $c.Help "$($c.File) · $($c.Runner)" }
    } else {
        Write-Host ("  {0}{1}{2}" -f $TK.dim, $T.cmds_empty, $TK.R)
    }
    if ($global:CustomFunctions) {
        Write-Host ''
        Write-Host ("  {0}custom.ps1{1}" -f $TK.title, $TK.R)
        foreach ($f in $global:CustomFunctions) { Write-TkRow $f ((Get-Command $f).Definition.Trim() -split "`n")[0].Trim() }
    }
    if ($global:Abbreviations.Count) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.title, $T.cmds_abbr, $TK.R, $TK.dim, $T.cmds_abbr_hint, $TK.R)
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
    }
    Write-Host ''
}

# ── history ──────────────────────────────────────────────────────────────────
if (Test-Path Alias:h) { Remove-Item Alias:h -Force }
function h {
    param([string]$Filter, [int]$Count = 50, [int]$PageSize = 10)
    $path = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path $path)) { return }

    # multi-line entries are stored as lines ending with a backtick
    $entries = [System.Collections.Generic.List[string]]::new()
    $buffer = ''
    foreach ($line in [IO.File]::ReadLines($path)) {
        if ($line.EndsWith('`')) { $buffer += $line.Substring(0, $line.Length - 1) + "`n"; continue }
        $entries.Add($buffer + $line); $buffer = ''
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $list = [System.Collections.Generic.List[string]]::new()
    for ($i = $entries.Count - 1; $i -ge 0 -and $list.Count -lt $Count; $i--) {
        $e = $entries[$i].Trim()
        if (-not $e -or $e -match '^h(\s|$)') { continue }
        if ($Filter -and $e.IndexOf($Filter, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        if ($seen.Add($e)) { $list.Add($e) }
    }

    Write-TkTitle $(if ($Filter) { $T.hist_filtered -f $Filter } else { $T.hist_title }) $T.hist_hint
    $paging = -not [Console]::IsInputRedirected
    for ($i = 0; $i -lt $list.Count; $i++) {
        $lines = $list[$i] -split "`n"
        $text = $lines[0]
        if ($Filter) { $text = $text -ireplace [regex]::Escape($Filter), ($TK.accent + '$0' + $TK.R) }
        if ($lines.Count -gt 1) { $text += "  $($TK.dim)$($T.hist_more -f ($lines.Count - 1))$($TK.R)" }
        Write-Host ("  {0}{1,3}{2}  {3}" -f $TK.dim, ($i + 1), $TK.R, $text)

        if ($paging -and ($i + 1) % $PageSize -eq 0 -and $i + 1 -lt $list.Count) {
            Write-Host -NoNewline ("  {0}{1}{2}" -f $TK.dim, ($T.hist_page -f ($i + 1), $list.Count), $TK.R)
            $key = [Console]::ReadKey($true).Key
            Write-Host -NoNewline "`r$([char]27)[2K"
            if ($key -in 'Q', 'Escape') { break }
        }
    }
    if (-not $list.Count) { Write-Host "  $($TK.dim)$($T.nothing_found)$($TK.R)" }
    Write-Host ''
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
        Write-TkTitle $T.abbr_title $T.abbr_hint
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
        Write-Host ''
        return
    }
    if (-not $Expansion) { Write-Host "  $($TK.err)$($T.abbr_usage)$($TK.R)"; return }
    $global:Abbreviations[$Name] = $Expansion
    # typed interactively (not sourced from a file) → persist to custom.ps1
    if ($MyInvocation.ScriptName -eq '' -and $global:isInteractive) {
        $line = "abbr $Name '$($Expansion.Replace("'", "''"))'"
        if (-not (Test-Path $custom) -or -not (Select-String -Path $custom -SimpleMatch $line -Quiet)) {
            Add-Content $custom "`n$line" -Encoding utf8
            Write-Host ("  {0}{1}{2}" -f $TK.dim, ($T.abbr_saved -f $line), $TK.R)
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

abbr g   'git'
abbr k   'kubectl'
abbr d   'docker'
abbr dc  'docker compose'
abbr gco 'git checkout'
abbr gp  'git push'
abbr gl  'git pull'
abbr gcm 'git commit -m "%"'
abbr kgp 'kubectl get pods'
abbr kga 'kubectl get all'

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
    if (Get-Command $first -ErrorAction SilentlyContinue) { return }
    $fixed = Convert-Layout $first
    if ($fixed -eq $first) { return }
    if (-not (Get-Command $fixed -ErrorAction SilentlyContinue) -and -not $global:Abbreviations.ContainsKey($fixed)) { return }
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
    if (($env:PATH -split ';') -notcontains $Dir) { $env:PATH = "$Dir;$env:PATH" }
    foreach ($f in Get-ChildItem $Dir -File | Sort-Object Name) {
        $name = $f.BaseName
        $ext = $f.Extension.ToLower()
        if (-not $global:ScriptRunners.Contains($ext) -or $name -notmatch '^[A-Za-z_][\w-]*$') { continue }
        # never shadow a real command; bin itself is on PATH, so ignore matches from there
        $taken = Get-Command $name -All -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notlike "$Dir\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
        if ($taken) { continue }
        $help = (Get-Content $f.FullName -First 15 | Select-String -Pattern '^\s*(#|//|;;|--)\s*help:\s*(.+)$' | Select-Object -First 1)
        $help = if ($help) { $help.Matches[0].Groups[2].Value.Trim() } else { '' }
        $runner = Get-ScriptRunner $ext
        $body = if ($runner) {
            $parts = ($runner -split ' ') | ForEach-Object { "'$_'" }
            "# UserCommand`n& $($parts -join ' ') '$($f.FullName)' @args"
        } else {
            "# UserCommand`nWrite-Host '  $($T.bin_norunner -f $f.Name, ($global:ScriptRunners[$ext] -join ' / '))'"
        }
        Set-Item "Function:global:$name" -Value ([scriptblock]::Create($body))
        $global:UserCommands += [pscustomobject]@{ Name = $name; File = $f.Name; Help = $help; Runner = $(if ($runner) { $runner } else { '— ' + ($global:ScriptRunners[$ext] -join '/') }); Path = $f.FullName }
    }
}

$TkTemplates = @{
    '.ps1' = "# help: {desc}`nparam([Parameter(ValueFromRemainingArguments)][string[]]`$Args)`n`n`"hello from {name}: `$Args`"`n"
    '.py'  = "# help: {desc}`n# /// script`n# dependencies = []`n# ///`nimport sys`n`n`ndef main(args: list[str]) -> None:`n    print(`"hello from {name}`", args)`n`n`nif __name__ == `"__main__`":`n    main(sys.argv[1:])`n"
    '.js'  = "// help: {desc}`nconsole.log('hello from {name}', process.argv.slice(2));`n"
    '.ts'  = "// help: {desc}`nconsole.log('hello from {name}', process.argv.slice(2));`n"
    '.sh'  = "#!/usr/bin/env bash`n# help: {desc}`necho `"hello from {name}: `$*`"`n"
    '.go'  = "// help: {desc}`npackage main`n`nimport (`n`t`"fmt`"`n`t`"os`"`n)`n`nfunc main() {`n`tfmt.Println(`"hello from {name}`", os.Args[1:])`n}`n"
    '.rs'  = "// help: {desc}`nfn main() {`n    let args: Vec<String> = std::env::args().skip(1).collect();`n    println!(`"hello from {name} {:?}`", args);`n}`n"
    '.clj' = ";; help: {desc}`n(println `"hello from {name}`" *command-line-args*)`n"
    '.rb'  = "# help: {desc}`nputs `"hello from {name}: #{ARGV.join(' ')}`"`n"
    '.lua' = "-- help: {desc}`nprint('hello from {name}', table.concat(arg, ' '))`n"
    '.php' = "<?php`n// help: {desc}`necho 'hello from {name}: ', implode(' ', array_slice(`$argv, 1)), PHP_EOL;`n"
}

function new {
    param([Parameter(Position = 0)][string]$FileName, [Parameter(Position = 1)][string]$Description)
    if (-not $Description) { $Description = $T.new_default }
    $bin = Join-Path $global:ProfileDir 'bin'
    if (-not $FileName) {
        Write-TkTitle $T.new_title ($T.new_hint -f $bin)
        foreach ($ext in $global:ScriptRunners.Keys) {
            $runner = Get-ScriptRunner $ext
            Write-TkRow "new name$ext" $(if ($runner) { $T.new_run -f $runner } else { $T.new_need -f ($global:ScriptRunners[$ext] -join ' / ') }) $(if ($runner) { '' } else { $T.new_missing })
        }
        Write-Host ''
        return
    }
    $ext = [IO.Path]::GetExtension($FileName).ToLower()
    $name = [IO.Path]::GetFileNameWithoutExtension($FileName)
    if (-not $TkTemplates.ContainsKey($ext)) { Write-Host "  $($TK.err)$($T.new_bad_ext -f $ext)$($TK.R)"; return }
    if ($name -notmatch '^[A-Za-z_][\w-]*$') { Write-Host "  $($TK.err)$($T.new_bad_name)$($TK.R)"; return }
    $taken = Get-Command $name -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike "$bin\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
    if ($taken) { Write-Host "  $($TK.err)$($T.new_taken -f $name, $taken.CommandType, $taken.Source)$($TK.R)"; return }
    New-Item -ItemType Directory -Force $bin | Out-Null
    $path = Join-Path $bin "$name$ext"
    if (-not (Test-Path $path)) {
        $text = $TkTemplates[$ext].Replace('{desc}', $Description).Replace('{name}', $name)
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
        Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, $path, $TK.R)
    }
    Register-BinCommands $bin
    $runner = Get-ScriptRunner $ext
    if ($runner) { Write-Host ("  {0}{1}{2}{3}{4} {5}{6}  {7}{8}{9}" -f $TK.dim, $T.new_ready, $TK.cmd, $name, $TK.R, $TK.dim, $T.new_args, $TK.dim, ($T.new_via -f $runner), $TK.R) }
    else { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($T.new_norunner -f ($global:ScriptRunners[$ext] -join ' / ')), $TK.R) }
    if (Get-Command code -ErrorAction SilentlyContinue) { code $path }
}

# ── theme / lang ─────────────────────────────────────────────────────────────
function Get-TerminalSettingsPaths {
    $paths = foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
        Join-Path $env:LOCALAPPDATA "Packages\$pkg\LocalState\settings.json"
    }
    $paths += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $paths | Where-Object { Test-Path $_ }
}

function theme {
    param([Parameter(Position = 0)][ArgumentCompleter({ param($c, $p, $word) $CatppuccinFlavors.Keys | Where-Object { $_ -like "$word*" } })][string]$Name)
    if (-not $Name) {
        Write-TkTitle $T.theme_title $T.theme_hint
        foreach ($f in $CatppuccinFlavors.Keys) {
            $p = $CatppuccinFlavors[$f]
            $swatch = ($p.red, $p.peach, $p.yellow, $p.green, $p.teal, $p.blue, $p.mauve | ForEach-Object { (_tkRgb $_) + '●' }) -join ' '
            $mark = if ($f -eq $global:ThemeName) { $TK.ok + '● ' } else { '  ' }
            Write-Host ("  {0}{1}{2,-10}{3} {4}{5}  {6}{7}{8}" -f $mark, $TK.cmd, $f, $TK.R, $swatch, $TK.R, $TK.dim, $(if ($p.dark) { $T.theme_dark } else { $T.theme_light }), $TK.R)
        }
        Write-Host ''
        return
    }
    $Name = $Name.ToLower()
    if (-not $CatppuccinFlavors.Contains($Name)) { Write-Host "  $($TK.err)$($T.theme_only -f ($CatppuccinFlavors.Keys -join ', '))$($TK.R)"; return }
    New-Item -ItemType Directory -Force (Split-Path $ThemeFile) | Out-Null
    [IO.File]::WriteAllText($ThemeFile, "$Name`n")
    $global:ThemeName = $Name
    $global:Palette = $CatppuccinFlavors[$Name]
    $env:TERMINAL_THEME = $Name
    Set-TerminalPalette
    $title = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Name))"
    foreach ($path in Get-TerminalSettingsPaths) {
        $raw = [IO.File]::ReadAllText($path)
        $new = $raw -replace '("colorScheme"\s*:\s*)"Catppuccin [A-Za-z]+"', "`$1`"$title`"" -replace '("theme"\s*:\s*)"Catppuccin [A-Za-z]+"', "`$1`"$title`""
        if ($new -ne $raw) { [IO.File]::WriteAllText($path, $new, [Text.UTF8Encoding]::new($false)) }
    }
    Write-Host ("  {0}✓ {1}{2}  {3}{4}{5}" -f $TK.ok, $title, $TK.R, $TK.dim, $T.theme_done, $TK.R)
}

function lang {
    param([Parameter(Position = 0)][ValidateSet('', 'ru', 'en')][string]$Name = '')
    if (-not $Name) {
        Write-TkTitle $T.lang_title $T.lang_hint
        foreach ($l in 'ru', 'en') {
            $mark = if ($l -eq $global:LangName) { $TK.ok + '● ' } else { '  ' }
            Write-Host ("  {0}{1}{2,-6}{3} {4}{5}{6}" -f $mark, $TK.cmd, $l, $TK.R, $TK.dim, $T["lang_$l"], $TK.R)
        }
        Write-Host ''
        return
    }
    New-Item -ItemType Directory -Force (Split-Path $LangFile) | Out-Null
    [IO.File]::WriteAllText($LangFile, "$Name`n")
    $global:LangName = $Name
    $global:T = $Strings[$Name]
    Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, ($T.lang_done -f $T["lang_$Name"]), $TK.R)
}

function ep { code $global:ProfileDir }
