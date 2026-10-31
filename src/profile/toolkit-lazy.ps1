# Loaded by Complete-Termistry right after the first prompt (PowerShell.OnIdle), so startup stays fast.

function global:Format-TkSize([double]$Bytes) {
    foreach ($u in $TkStr.units) { if ($Bytes -lt 1024) { return ('{0:N1} {1}' -f $Bytes, $u) -replace '[.,]0 ', ' ' }; $Bytes /= 1024 }
    '{0:N1} {1}' -f $Bytes, $TkStr.units[-1]
}

# docker/kubectl can hang for a long time when their daemon is down
function global:Invoke-WithTimeout([string]$Command, [string[]]$Arguments, [int]$Milliseconds = 3000) {
    $exe = (Find-TkCommand $Command).Source
    if (-not $exe) { return $null }
    $psi = [Diagnostics.ProcessStartInfo]::new($exe)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEndAsync()
    if (-not $proc.WaitForExit($Milliseconds)) { try { $proc.Kill() } catch {}; return $null }
    if ($proc.ExitCode -ne 0) { return $null }
    $out.Result -split "`r?`n" | Where-Object { $_.Trim() }
}

# ── help ─────────────────────────────────────────────────────────────────────
function global:Get-TkUserSection {
    $rows = @()
    foreach ($c in $global:UserCommands) { $rows += , ($c.Name, $c.Help, ("bin\" + $c.File)) }
    foreach ($f in $global:CustomFunctions) { $rows += , ($f, $TkStr.help_custom) }
    if ($global:Abbreviations.Count) {
        $list = ($global:Abbreviations.GetEnumerator() | Select-Object -First 4 | ForEach-Object { "$($_.Key)→$($_.Value)" }) -join '  '
        if ($global:Abbreviations.Count -gt 4) { $list += '  ' + ($TkStr.help_more -f ($global:Abbreviations.Count - 4)) }
        $rows += , ('abbr', $list, $TkStr.help_abbr_all)
    }
    if ($rows) { @{ Key = 'my'; Title = $TkStr.help_user; Rows = $rows } }
}

function global:Get-TkAllSections { @($TkStr.sections) + @(Get-TkUserSection) }

function global:Show-TkHelp($Sections) {
    if (-not $Sections) { $Sections = Get-TkAllSections }
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}: {6}{7}" -f $TK.title, $TK.B, $TkStr.help_title, $TK.R, $TK.dim, $TkStr.help_theme, $global:ThemeName, $TK.R)
    Write-Host ("  {0}{1}{2}" -f $TK.dim, $TkStr.help_hint, $TK.R)
    foreach ($s in $Sections) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}{3}  {4}help {5}{6}" -f $TK.title, $TK.B, $s.Title, $TK.R, $TK.dim, $s.Key, $TK.R)
        foreach ($r in $s.Rows) { Write-TkRow @r }
    }
    Write-Host ''
}

function global:help {
    if (-not $args) { Show-TkHelp; return }
    $query = "$args"
    $all = Get-TkAllSections
    $section = $all | Where-Object { $_.Key -eq $query -or $_.Title -eq $query }
    if ($section) { Show-TkHelp $section; return }

    $hits = @(foreach ($s in $all) {
        foreach ($r in $s.Rows) { if (($r -join ' ').IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) { , $r } }
    })
    $isCmdlet = Get-Command $query -CommandType Cmdlet, Alias -ErrorAction Ignore
    if ($hits -and $args.Count -eq 1 -and -not $isCmdlet) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}: {3}{4}" -f $TK.title, $TK.B, $TkStr.help_found, $query, $TK.R)
        foreach ($r in $hits) { Write-TkRow @r }
        Write-Host ''
        return
    }
    try { Get-Help @args -ErrorAction Stop } catch { Write-Host "  $($TK.dim)$($TkStr.nothing_found)$($TK.R)" }
}

function global:Invoke-HelpPicker {
    $lines = foreach ($s in Get-TkAllSections) {
        foreach ($r in $s.Rows) {
            $cmd = $r[0]; $desc = $r[1]
            $shown = '{0,-28} {1}' -f $cmd, $desc
            if ($r.Count -gt 2 -and $r[2]) { $shown += "   $($r[2])" }
            $insert = if ($cmd -match $TkStr.no_insert) { '' } else { ($cmd -split ' / | · | \[| <')[0].Trim() }
            "{0,-12}  {1}`t{2}" -f $s.Title, $shown, $insert
        }
    }
    $exit = $global:LASTEXITCODE
    $pick = $lines | fzf --height=60% --prompt='help ❯ ' "--header=$($TkStr.picker_header)" --delimiter="`t" --with-nth=1 --tabstop=4
    # fzf's exit code is not the user's: redraw the prompt as it was
    $global:LASTEXITCODE = $exit
    $global:TsRedraw = $true
    try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } finally { $global:TsRedraw = $false }
    if ($pick) {
        $insert = ($pick -split "`t")[1]
        if ($insert) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($insert) }
    }
}

# ── ssh ──────────────────────────────────────────────────────────────────────
function global:Get-SshHost {
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

function global:Select-SshHost([string]$Query, [string]$Header) {
    $hosts = @(Get-SshHost)
    if (-not $hosts) { Write-Host "  $($TkStr.ssh_empty)"; return }
    $width = ($hosts.Name | Measure-Object Length -Maximum).Maximum
    $pick = $hosts | ForEach-Object { '{0}  {1}@{2}' -f $_.Name.PadRight($width), $_.User, $_.HostName } |
        fzf --query=$Query --select-1 --height=14 --header=$Header
    if ($pick) { ($pick -split '\s+')[0] }
}

function global:jump([string]$Query) {
    $name = Select-SshHost $Query $TkStr.jump_header
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
function global:srv {
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
        if (-not (Test-Path (Join-Path $dir $f))) { Write-Host "  $($TK.err)$($TkStr.srv_missing -f "$dir\$f")$($TK.R)"; return }
    }
    if ($Env -and $Env -notmatch '^[A-Za-z0-9_-]{1,20}$') { Write-Host "  $($TK.err)$($TkStr.srv_env)$($TK.R)"; return }
    if (-not $Hosts) {
        $picked = Select-SshHost '' ($TkStr.srv_pick -f $Action)
        if (-not $picked) { return }
        $Hosts = @($picked)
    }
    if (-not $Lang) { $Lang = $global:LangName }

    $read = { param($path) [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }
    $b64 = { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
    $custom = foreach ($f in Get-ChildItem (Join-Path $dir 'custom') -File -Filter *.sh -ErrorAction Ignore) {
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
        if ($LASTEXITCODE -eq 0 -and $Action -eq 'remove') { Write-Host "  $($TK.ok)$($TkStr.srv_removed)$($TK.R) $($TK.dim)$($TkStr.srv_restore -f $h)$($TK.R)" }
        elseif ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)$($TkStr.srv_done)$($TK.R) $($TK.dim)$($TkStr.srv_relogin -f $h)$($TK.R)" }
        else { Write-Host "  $($TK.err)$($TkStr.srv_error -f $LASTEXITCODE)$($TK.R)" }
        Write-Host ''
    }
}

function global:Show-SrvHelp([string]$Dir) {
    Write-TkTitle $TkStr.srv_title ($TkStr.srv_templates -f $Dir)
    foreach ($r in $TkStr.srv_rows) { Write-TkRow @r }
    Write-Host ''
    Write-Host "  $($TK.title)$($TkStr.srv_gets)$($TK.R)"
    foreach ($line in $TkStr.srv_gets_rows) { Write-Host "    $line" }
    Write-Host ''
    Write-Host "  $($TK.title)$($TkStr.srv_custom)$($TK.R)"
    foreach ($line in $TkStr.srv_custom_rows) { Write-Host "    $($line -f $Dir)" }
    Write-Host ''
    Write-Host "  $($TK.dim)$($TkStr.srv_note)$($TK.R)"
    Write-Host ''
}

# ── my ───────────────────────────────────────────────────────────────────────
function global:my {
    param(
        [Parameter(Position = 0)][ArgumentCompleter({
            param($c, $p, $word) $TkStr.my_topics.get_Keys() | Where-Object { $_ -like "$word*" }
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
        'config' { Show-MyConfig }
        'keys'   { Show-TkHelp ($TkStr.sections | Where-Object { $_.Key -in 'keys', 'input' }) }
        default {
            Write-TkTitle $TkStr.my_title $TkStr.my_hint
            # get_Keys(): the dictionary has a 'keys' entry, so .Keys would return it
            foreach ($k in $TkStr.my_topics.get_Keys()) { Write-TkRow "my $k" $TkStr.my_topics[$k] }
            Write-Host ''
        }
    }
}

function global:Show-MySys {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    Write-TkTitle $env:COMPUTERNAME (($TkStr.sys_uptime -f [int]$up.TotalDays, $up.Hours, $up.Minutes) + ' · ' + $os.Caption.Replace('Microsoft ', ''))
    $cpuName = ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)|CPU|Processor', '').Trim()
    $row = { param($label, $percent, $note) Write-Host ("  {0}{1}{2}  {3}  {4}{5}{6}" -f $TK.dim, $label.PadRight(10), $TK.R, (Get-TkBar $percent), $TK.dim, $note, $TK.R) }
    & $row $TkStr.sys_cpu $cpu.LoadPercentage "$cpuName · $($TkStr.sys_cores): $([Environment]::ProcessorCount)"
    $memUsed = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
    $memTotal = $os.TotalVisibleMemorySize * 1KB
    & $row $TkStr.sys_mem ($memUsed / $memTotal * 100) "$(Format-TkSize $memUsed) $($TkStr.of) $(Format-TkSize $memTotal)"
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object DeviceID) {
        if (-not $d.Size) { continue }
        $used = $d.Size - $d.FreeSpace
        & $row "$($TkStr.sys_disk) $($d.DeviceID)" ($used / $d.Size * 100) "$(Format-TkSize $used) $($TkStr.of) $(Format-TkSize $d.Size)$(if ($d.VolumeName) { " · $($d.VolumeName)" })"
    }

    Write-Host ''
    Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.sys_bymem, $TK.R)
    $top = Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Memory = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum; Count = $_.Count }
    } | Sort-Object Memory -Descending | Select-Object -First 6
    foreach ($t in $top) {
        Write-Host ("  {0}{1,-26}{2} {3,9}{4}{5}" -f $TK.cmd, $t.Name, $TK.R, (Format-TkSize $t.Memory), $TK.dim, $(if ($t.Count -gt 1) { "  ×$($t.Count)" }), $TK.R)
    }

    if (Find-TkCommand docker) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.sys_containers, $TK.R)
        $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}')
        if ($null -eq $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_down)$($TK.R)" }
        elseif (-not $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_none)$($TK.R)" }
        foreach ($r in $rows) {
            $name, $state = $r -split "`t"
            $dot = if ($state -match 'unhealthy|Restarting') { $TK.err } elseif ($state -like 'Up*') { $TK.ok } elseif ($state -like 'Exited (0)*') { $TK.dim } else { $TK.err }
            Write-Host ("  {0}●{1} {2,-30} {3}{4}{5}" -f $dot, $TK.R, $name, $TK.dim, $state, $TK.R)
        }
    }
    Write-Host ''
}

function global:Show-MyK8s {
    if (-not (Find-TkCommand kubectl)) { Write-Host "  $($TK.dim)$($TkStr.k8s_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout kubectl @('config', 'get-contexts', '--no-headers') 5000
    Write-TkTitle 'Kubernetes' $TkStr.k8s_hint
    if (-not $rows) { Write-Host "  $($TK.dim)$($TkStr.k8s_none)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $f = $r.Trim() -split '\s+'
        $cur = $f[0] -eq '*'
        if ($cur) { $f = $f[1..($f.Count - 1)] }
        [pscustomobject]@{ Mark = $(if ($cur) { '●' } else { ' ' }); Name = $f[0]; Cluster = $f[1]; Namespace = $(if ($f.Count -gt 3) { $f[3] } else { 'default' }) }
    }
    Write-TkTable $list @(
        @{ N = ' '; P = 'Mark'; C = 'ok' }
        @{ N = $TkStr.col_context; P = 'Name'; C = { param($r) if ($r.Mark -eq '●') { 'cmd' } else { 'text' } } }
        @{ N = $TkStr.col_cluster; P = 'Cluster'; C = 'dim' }
        @{ N = 'Namespace'; P = 'Namespace'; C = 'accent' }
    )
    Write-Host ''
}

function global:Show-MyDocker {
    if (-not (Find-TkCommand docker)) { Write-Host "  $($TK.dim)$($TkStr.docker_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}\t{{.Ports}}')
    Write-TkTitle 'Docker' $TkStr.docker_hint
    if ($null -eq $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_down)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $name, $state, $ports = $r -split "`t"
        $ports = ($ports -replace '0\.0\.0\.0:|\[::\]:|/tcp', '' -split ', ' | Sort-Object -Unique) -join ' '
        [pscustomobject]@{ Dot = '●'; Name = $name; State = $state; Ports = $ports }
    }
    if (-not $list) { Write-Host "  $($TK.dim)$($TkStr.docker_none)$($TK.R)" }
    else {
        Write-TkTable $list @(
            @{ N = ' '; P = 'Dot'; C = { param($r) if ($r.State -match 'unhealthy|Restarting') { 'err' } elseif ($r.State -like 'Up*') { 'ok' } elseif ($r.State -like 'Exited (0)*') { 'dim' } else { 'err' } } }
            @{ N = $TkStr.col_container; P = 'Name'; C = 'cmd' }
            @{ N = $TkStr.col_status; P = 'State'; C = 'dim' }
            @{ N = $TkStr.col_ports; P = 'Ports'; C = 'accent' }
        )
    }
    $projects = Invoke-WithTimeout docker @('compose', 'ls', '-a', '--format', '{{.Name}}\t{{.Status}}\t{{.ConfigFiles}}') 5000
    if ($projects) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.docker_projects, $TK.R)
        foreach ($p in $projects) {
            $name, $state, $files = $p -split "`t"
            Write-Host ("  {0}{1,-20}{2} {3,-24} {4}{5}{6}" -f $TK.cmd, $name, $TK.R, $state, $TK.dim, (Split-Path ($files -split ',')[0]), $TK.R)
        }
    }
    Write-Host ''
}

function global:Show-MySsh([string]$Filter) {
    $hosts = @(Get-SshHost | Where-Object { -not $Filter -or "$($_.Name) $($_.HostName) $($_.User)" -like "*$Filter*" })
    Write-TkTitle $TkStr.ssh_title $TkStr.ssh_hint
    if (-not $hosts) { Write-Host "  $($TK.dim)$($TkStr.nothing_found)$($TK.R)"; Write-Host ''; return }
    Write-TkTable $hosts @(
        @{ N = $TkStr.col_name; P = 'Name'; C = 'cmd' }
        @{ N = $TkStr.col_address; P = 'HostName'; C = 'text' }
        @{ N = $TkStr.col_user; P = 'User'; C = { param($r) if ($r.User -eq 'root') { 'err' } else { 'ok' } } }
        @{ N = $TkStr.col_port; P = 'Port'; C = 'dim' }
        @{ N = $TkStr.col_key; P = 'IdentityFile'; C = 'dim' }
    )
    foreach ($d in $hosts | Where-Object Duplicate) { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($TkStr.ssh_dup -f $d.Name, $d.User), $TK.R) }
    Write-Host ''
}

function global:Show-MyIp([string]$Mode) {
    $rows = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Ignore |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Sort-Object InterfaceMetric |
        ForEach-Object { [pscustomobject]@{ Interface = $_.InterfaceAlias; Address = "$($_.IPAddress)/$($_.PrefixLength)" } }
    Write-TkTitle $TkStr.ip_title $TkStr.ip_hint
    Write-TkTable $rows @(@{ N = $TkStr.col_iface; P = 'Interface'; C = 'text' }, @{ N = $TkStr.col_address; P = 'Address'; C = 'cmd' })
    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Ignore | Sort-Object RouteMetric | Select-Object -First 1
    if ($gw) { Write-Host ("  {0}{1}{2}  {3} {4}({5}){6}" -f $TK.dim, $TkStr.ip_gateway, $TK.R, $gw.NextHop, $TK.dim, $gw.InterfaceAlias, $TK.R) }
    if ($Mode -eq 'public') {
        try { $ip = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5; Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.dim, $TkStr.ip_public, $TK.R, $TK.accent, $ip, $TK.R) }
        catch { Write-Host "  $($TK.err)$($TkStr.ip_public_fail)$($TK.R)" }
    }
    Write-Host ''
}

function global:Show-MyPorts([string]$Filter) {
    $names = @{}; Get-Process | ForEach-Object { $names[$_.Id] = $_.ProcessName }
    $all = Get-NetTCPConnection -State Listen -ErrorAction Ignore | Group-Object LocalPort | ForEach-Object {
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
    Write-TkTitle $TkStr.ports_title $TkStr.ports_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_port; P = 'Port'; C = 'accent' }
        @{ N = $TkStr.col_process; P = 'Process'; C = 'cmd' }
        @{ N = 'PID'; P = 'PID'; C = 'dim' }
        @{ N = $TkStr.col_address; P = 'Address'; C = 'dim' }
    )
    Write-Host ''
}

function global:Show-MyPath {
    $seen = @{}
    $rows = foreach ($p in $env:PATH -split ';' | Where-Object { $_ }) {
        $state = if ($seen.ContainsKey($p.TrimEnd('\'))) { $TkStr.path_dup } elseif (-not (Test-Path $p)) { $TkStr.path_missing } else { '' }
        $seen[$p.TrimEnd('\')] = $true
        [pscustomobject]@{ Path = $p; State = $state }
    }
    Write-TkTitle $TkStr.path_title $TkStr.path_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_folder; P = 'Path'; C = { param($r) if ($r.State) { 'dim' } else { 'text' } } }
        @{ N = ''; P = 'State'; C = { param($r) if ($r.State -eq $TkStr.path_dup) { 'warn' } else { 'err' } } }
    )
    Write-Host ''
}

function global:Show-MyTools {
    $specs = [ordered]@{
        pwsh = '--version'; git = '--version'; gh = '--version'; lazygit = '--version'; node = '--version'; python = '--version'
        uv = '--version'; docker = '--version'; kubectl = 'version --client'; helm = 'version --short'; kind = 'version'
        minikube = 'version --short'; code = '--version'; fzf = '--version'; zoxide = '--version'
        eza = '--version'; bat = '--version'; rg = '--version'; fd = '--version'; delta = '--version'; tldr = '--version'
    }
    $rows = $specs.GetEnumerator() | ForEach-Object -ThrottleLimit 10 -Parallel {
        $name, $argLine = $_.Key, $_.Value
        $cmd = Get-Command $name -ErrorAction Ignore | Select-Object -First 1
        if (-not $cmd) { return }
        $out = (& $name ($argLine -split ' ') 2>&1 | Select-Object -First 3) -join ' '
        [pscustomobject]@{ Name = $name; Version = ([regex]::Match($out, '\d+\.\d+(\.\d+)?')).Value; Path = $cmd.Source }
    } | Sort-Object Name
    Write-TkTitle $TkStr.tools_title $TkStr.tools_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_program; P = 'Name'; C = 'cmd' }
        @{ N = $TkStr.col_version; P = 'Version'; C = 'ok' }
        @{ N = $TkStr.col_where; P = 'Path'; C = 'dim' }
    )
    Write-Host ''
}

function global:Show-MyGit {
    Write-TkTitle 'Git' ''
    Write-TkRow $TkStr.git_name (git config --global user.name)
    Write-TkRow $TkStr.git_email (git config --global user.email)
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) {
        Write-TkRow $TkStr.git_repo $root
        Write-TkRow $TkStr.git_branch (git branch --show-current)
        foreach ($r in git remote -v | Where-Object { $_ -like '*(fetch)' }) {
            $name, $url = $r -split '\s+'
            Write-TkRow "remote $name" $url
        }
    } else {
        Write-Host "    $($TK.dim)$($TkStr.git_none)$($TK.R)"
    }
    $aliases = git config --global --get-regexp '^alias\.' 2>$null
    foreach ($a in $aliases) { $k, $v = $a -split ' ', 2; Write-TkRow ('git ' + $k.Substring(6)) $v }
    Write-Host ''
}

function global:Show-MyCommands {
    Write-TkTitle $TkStr.cmds_title ($TkStr.cmds_hint -f $global:ProfileDir)
    if ($global:UserCommands) {
        Write-Host ("  {0}bin\{1}" -f $TK.title, $TK.R)
        foreach ($c in $global:UserCommands) {
            $runner = Get-ScriptRunner $c.Extension
            Write-TkRow $c.Name $c.Help "$($c.File) · $(if ($runner) { $runner } else { '- ' + ($global:ScriptRunners[$c.Extension] -join '/') })"
        }
    } else {
        Write-Host ("  {0}{1}{2}" -f $TK.dim, $TkStr.cmds_empty, $TK.R)
    }
    if ($global:CustomFunctions) {
        Write-Host ''
        Write-Host ("  {0}custom.ps1{1}" -f $TK.title, $TK.R)
        foreach ($f in $global:CustomFunctions) { Write-TkRow $f ((Get-Command $f).Definition.Trim() -split "`n")[0].Trim() }
    }
    if ($global:Abbreviations.Count) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.title, $TkStr.cmds_abbr, $TK.R, $TK.dim, $TkStr.cmds_abbr_hint, $TK.R)
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
    }
    Write-Host ''
}

# ── history ──────────────────────────────────────────────────────────────────
if (Test-Path Alias:h) { Remove-Item Alias:h -Force }
function global:h {
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

    Write-TkTitle $(if ($Filter) { $TkStr.hist_filtered -f $Filter } else { $TkStr.hist_title }) $TkStr.hist_hint
    $paging = -not [Console]::IsInputRedirected
    for ($i = 0; $i -lt $list.Count; $i++) {
        $lines = $list[$i] -split "`n"
        $text = $lines[0]
        if ($Filter) { $text = $text -ireplace [regex]::Escape($Filter), ($TK.accent + '$0' + $TK.R) }
        if ($lines.Count -gt 1) { $text += "  $($TK.dim)$($TkStr.hist_more -f ($lines.Count - 1))$($TK.R)" }
        Write-Host ("  {0}{1,3}{2}  {3}" -f $TK.dim, ($i + 1), $TK.R, $text)

        if ($paging -and ($i + 1) % $PageSize -eq 0 -and $i + 1 -lt $list.Count) {
            Write-Host -NoNewline ("  {0}{1}{2}" -f $TK.dim, ($TkStr.hist_page -f ($i + 1), $list.Count), $TK.R)
            $key = [Console]::ReadKey($true).Key
            Write-Host -NoNewline "`r$([char]27)[2K"
            if ($key -in 'Q', 'Escape') { break }
        }
    }
    if (-not $list.Count) { Write-Host "  $($TK.dim)$($TkStr.nothing_found)$($TK.R)" }
    Write-Host ''
}

$global:TkTemplates = @{
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

function global:new {
    param([Parameter(Position = 0)][string]$FileName, [Parameter(Position = 1)][string]$Description)
    if (-not $Description) { $Description = $TkStr.new_default }
    $bin = Join-Path $global:ProfileDir 'bin'
    if (-not $FileName) {
        Write-TkTitle $TkStr.new_title ($TkStr.new_hint -f $bin)
        foreach ($ext in $global:ScriptRunners.Keys) {
            $runner = Get-ScriptRunner $ext
            Write-TkRow "new name$ext" $(if ($runner) { $TkStr.new_run -f $runner } else { $TkStr.new_need -f ($global:ScriptRunners[$ext] -join ' / ') }) $(if ($runner) { '' } else { $TkStr.new_missing })
        }
        Write-Host ''
        return
    }
    $ext = [IO.Path]::GetExtension($FileName).ToLower()
    $name = [IO.Path]::GetFileNameWithoutExtension($FileName)
    if (-not $TkTemplates.ContainsKey($ext)) { Write-Host "  $($TK.err)$($TkStr.new_bad_ext -f $ext)$($TK.R)"; return }
    if ($name -notmatch '^[A-Za-z_][\w-]*$') { Write-Host "  $($TK.err)$($TkStr.new_bad_name)$($TK.R)"; return }
    $taken = Find-TkCommand $name -All |
        Where-Object { $_.Source -notlike "$bin\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
    if ($taken) { Write-Host "  $($TK.err)$($TkStr.new_taken -f $name, $taken.CommandType, $taken.Source)$($TK.R)"; return }
    New-Item -ItemType Directory -Force $bin | Out-Null
    $path = Join-Path $bin "$name$ext"
    if (-not (Test-Path $path)) {
        $text = $TkTemplates[$ext].Replace('{desc}', $Description).Replace('{name}', $name)
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
        Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, $path, $TK.R)
    }
    Register-BinCommands $bin
    $runner = Get-ScriptRunner $ext
    if ($runner) { Write-Host ("  {0}{1}{2}{3}{4} {5}{6}  {7}{8}{9}" -f $TK.dim, $TkStr.new_ready, $TK.cmd, $name, $TK.R, $TK.dim, $TkStr.new_args, $TK.dim, ($TkStr.new_via -f $runner), $TK.R) }
    else { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($TkStr.new_norunner -f ($global:ScriptRunners[$ext] -join ' / ')), $TK.R) }
    if ($global:isInteractive -and (Find-TkCommand code)) { code $path }
}

# ── theme / lang ─────────────────────────────────────────────────────────────
function global:Get-TerminalSettingsPaths {
    $paths = foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
        Join-Path $env:LOCALAPPDATA "Packages\$pkg\LocalState\settings.json"
    }
    $paths += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $paths | Where-Object { Test-Path $_ }
}

function global:theme {
    param([Parameter(Position = 0)][ArgumentCompleter({ param($c, $p, $word) $Themes.Keys | Where-Object { $_ -like "$word*" } })][string]$Name)
    if (-not $Name) {
        Write-TkTitle $TkStr.theme_title $TkStr.theme_hint
        foreach ($f in $Themes.Keys) {
            $p = $Themes[$f]
            $swatch = ($p.red, $p.peach, $p.yellow, $p.green, $p.teal, $p.blue, $p.mauve | ForEach-Object { (_tkRgb $_) + '●' }) -join ' '
            $mark = if ($f -eq $global:ThemeName) { $TK.ok + '● ' } else { '  ' }
            $kind = if ($p.dark) { $TkStr.theme_dark } else { $TkStr.theme_light }
            Write-Host ("  {0}{1}{2,-11}{3} {4}{5}  {6}{7,-20} {8}{9}{10}" -f $mark, $TK.cmd, $f, $TK.R, $swatch, $TK.R, $TK.text, $p.title, $TK.dim, $kind, $TK.R)
        }
        Write-Host ''
        return
    }
    $Name = $Name.ToLower()
    if (-not $Themes.Contains($Name)) { Write-Host "  $($TK.err)$($TkStr.theme_only -f ($Themes.Keys -join ', '))$($TK.R)"; return }
    New-Item -ItemType Directory -Force (Split-Path $ThemeFile) | Out-Null
    [IO.File]::WriteAllText($ThemeFile, "$Name`n")
    $global:ThemeName = $Name
    $global:Palette = $Themes[$Name]
    $env:TERMINAL_THEME = $Name
    Set-TerminalPalette
    $title = $Themes[$Name].title
    $known = ($Themes.Values.title + 'Catppuccin [A-Za-z]+' | ForEach-Object { if ($_ -like 'Catppuccin [[]*') { $_ } else { [regex]::Escape($_) } }) -join '|'
    foreach ($path in Get-TerminalSettingsPaths) {
        $raw = [IO.File]::ReadAllText($path)
        $new = $raw -replace "(`"colorScheme`"\s*:\s*)`"($known)`"", "`$1`"$title`"" -replace "(`"theme`"\s*:\s*)`"($known)`"", "`$1`"$title`""
        if ($new -ne $raw) { [IO.File]::WriteAllText($path, $new, [Text.UTF8Encoding]::new($false)) }
    }
    Write-Host ("  {0}✓ {1}{2}  {3}{4}{5}" -f $TK.ok, $title, $TK.R, $TK.dim, $TkStr.theme_done, $TK.R)
}

function global:lang {
    param([Parameter(Position = 0)][ValidateSet('', 'ru', 'en')][string]$Name = '')
    if (-not $Name) {
        Write-TkTitle $TkStr.lang_title $TkStr.lang_hint
        foreach ($l in 'ru', 'en') {
            $mark = if ($l -eq $global:LangName) { $TK.ok + '● ' } else { '  ' }
            Write-Host ("  {0}{1}{2,-6}{3} {4}{5}{6}" -f $mark, $TK.cmd, $l, $TK.R, $TK.dim, $TkStr["lang_$l"], $TK.R)
        }
        Write-Host ''
        return
    }
    New-Item -ItemType Directory -Force (Split-Path $LangFile) | Out-Null
    [IO.File]::WriteAllText($LangFile, "$Name`n")
    $global:LangName = $Name
    $global:TkStr = $Strings[$Name]
    Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, ($TkStr.lang_done -f $TkStr["lang_$Name"]), $TK.R)
}

function global:ep { code $global:ProfileDir }

# ── fzf helpers ──────────────────────────────────────────────────────────────
# PowerShell piping into fzf throws "pipe is being closed" when fzf exits before the producer is done;
# short lists go through Invoke-Fzf, long ones (fd, rg) are started by fzf itself via FZF_DEFAULT_COMMAND.
function global:Invoke-Fzf([string[]]$Lines, [string[]]$Arguments) {
    try { @($Lines | fzf @Arguments) } catch { if ("$_" -notmatch 'pipe|канал') { throw } }
}

function global:Invoke-FzfCommand([string]$Command, [string[]]$Arguments) {
    $saved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = $Command
    try { @(fzf @Arguments) } finally { $env:FZF_DEFAULT_COMMAND = $saved }
}

# Preview script for fzf: folders through eza, files through bat. cmd runs it with UTF-8 so Cyrillic paths work.
function global:Get-TsPreview {
    $p = "$HOME\.cache\termistry\preview.cmd"
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
        $lines = '@echo off', 'chcp 65001 >nul', 'if exist "%~1\" (', '  eza --icons=always --color=always --group-directories-first -1 "%~1"', ') else (', '  bat --color=always --style=numbers,header-filename --line-range :300 "%~1"', ')'
        [IO.File]::WriteAllLines($p, $lines, [Text.ASCIIEncoding]::new())
    }
    $p
}

function global:Open-TsFile([string]$Path) {
    if (Find-TkCommand code) { code $Path } else { Invoke-Item $Path }
}

# ── nav: folders (and files with Ctrl+E) as a tree on fzf ────────────────────
function global:nav {
    param([string]$Start = (Get-Location).Path)
    if (-not (Find-TkCommand fzf)) { return }
    $dir = (Resolve-Path -LiteralPath $Start).Path
    $preview = "$(Get-TsPreview) {2}"
    $files = $false; $hidden = $false
    while ($true) {
        $parent = Split-Path $dir -Parent
        $entries = @()
        if ($parent) { $entries += "..`t$parent`td" }
        $items = @(Get-ChildItem -LiteralPath $dir -Force:$hidden -ErrorAction Ignore | Where-Object { $files -or $_.PSIsContainer })
        $entries += $items | Sort-Object { -not $_.PSIsContainer }, Name | ForEach-Object {
            if ($_.PSIsContainer) { "$($_.Name)`t$($_.FullName)`td" } else { "  $($_.Name)`t$($_.FullName)`tf" }
        }
        $mode = @(if ($files) { 'files' }; if ($hidden) { 'hidden' }) -join ' '
        $out = Invoke-Fzf $entries @('--expect=right,left,ctrl-f,ctrl-o,ctrl-e,ctrl-h', "--delimiter=`t", '--with-nth=1', '--cycle', '--height=70%',
            "--header=$($TkStr.nav_header)", "--prompt=$($dir.Replace($HOME, '~')) $(if ($mode) { "[$mode] " })❯ ", "--preview=$preview", '--preview-window=right:50%')
        if (-not $out) { return }
        $key = $out[0]
        $fields = if ($out.Count -gt 1) { $out[1] -split "`t" } else { $null }
        $sel = if ($fields) { $fields[1] } else { $null }
        $isDir = $fields -and $fields[2] -eq 'd'
        switch ($key) {
            'left'   { if ($parent) { $dir = $parent } }
            'right'  { if ($sel -and $isDir) { $dir = $sel } }
            'ctrl-e' { $files = -not $files }
            'ctrl-h' { $hidden = -not $hidden }
            'ctrl-o' { Invoke-Item $dir }
            'ctrl-f' {
                $cmd = "fd --hidden --exclude .git --exclude node_modules --type d$(if ($files) { ' --type f' }) . `"$dir`""
                $pick = Invoke-FzfCommand $cmd @('--height=70%', "--prompt=$($TkStr.nav_deep -f $dir.Replace($HOME, '~')) ❯ ", "--preview=$(Get-TsPreview) {}", '--preview-window=right:50%')
                if ($pick) {
                    if (Test-Path -LiteralPath $pick -PathType Container) { Set-Location -LiteralPath $pick } else { Open-TsFile $pick }
                }
                return
            }
            default {
                if (-not $sel) { Set-Location -LiteralPath $dir; return }
                if ($isDir) { Set-Location -LiteralPath $sel } else { Open-TsFile $sel }
                return
            }
        }
    }
}

# ── pv: files with a preview pane; rgi: live grep; pk: kill picker; gbr: branch picker ──
function global:pv {
    param([string]$Dir = '.', [string]$Query = '')
    $dir = (Resolve-Path -LiteralPath $Dir).Path
    $out = Invoke-FzfCommand "fd --type f --hidden --exclude .git --exclude node_modules . `"$dir`"" @('--expect=ctrl-p,ctrl-y', "--query=$Query", '--height=80%',
        "--header=$($TkStr.pv_header)", "--prompt=$($TkStr.pv_prompt) ❯ ", "--preview=$(Get-TsPreview) {}", '--preview-window=right:60%')
    if ($out.Count -lt 2) { return }
    $file = $out[1]
    switch ($out[0]) {
        'ctrl-p' { bat --color=always --style=numbers,header-filename --paging=never $file }
        'ctrl-y' { Set-Clipboard $file; Write-Host "  $($TK.dim)$file$($TK.R)" }
        default  { Open-TsFile $file }
    }
}

function global:rgi {
    param([string]$Text = '', [string]$Dir = '.')
    Push-Location -LiteralPath $Dir
    try {
        $rg = 'rg --line-number --no-heading --color=always --smart-case --hidden --glob !.git --glob !node_modules -- {q} .'
        $initial = if ($Text) { $rg.Replace('{q}', "`"$Text`"") } else { 'cd.' }
        $out = Invoke-FzfCommand $initial @('--disabled', '--ansi', "--query=$Text", '--expect=ctrl-y', '--delimiter=:', '--height=80%',
            "--header=$($TkStr.rgi_header)", '--prompt=rg ❯ ', "--bind=change:reload:$rg",
            '--preview=bat --color=always --style=numbers --highlight-line {2} {1}', '--preview-window=right:55%,+{2}-10')
        if ($out.Count -lt 2) { return }
        $file, $line = ($out[1] -split ':', 3)[0, 1]
        $full = (Resolve-Path -LiteralPath $file).Path
        if ($out[0] -eq 'ctrl-y') { Set-Clipboard "${full}:$line"; Write-Host "  $($TK.dim)${full}:$line$($TK.R)"; return }
        if (Find-TkCommand code) { code -g "${full}:$line" }
        else { bat --color=always --style=numbers --highlight-line $line --paging=never $full }
    } finally { Pop-Location }
}

function global:pk([string]$Name) {
    $procs = Get-Process | Where-Object { -not $Name -or $_.ProcessName -like "*$Name*" } | Sort-Object WorkingSet64 -Descending
    $lines = $procs | ForEach-Object { "{0,-28} {1,10} {2,7}  {3}`t{2}`t{0}" -f $_.ProcessName, (Format-TkSize $_.WorkingSet64), $_.Id, $_.MainWindowTitle }
    $out = Invoke-Fzf $lines @('--multi', '--height=60%', "--header=$($TkStr.pk_header)", '--prompt=kill ❯ ', "--delimiter=`t", '--with-nth=1')
    foreach ($line in $out) {
        $fields = $line -split "`t"
        try { Stop-Process -Id ([int]$fields[1]) -Force -ErrorAction Stop; Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.pk_done -f $fields[2])" }
        catch { Write-Host "  $($TK.err)$($fields[2]): $($_.Exception.Message)$($TK.R)" }
    }
}

function global:gbr {
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) { Write-Host "  $($TK.dim)$($TkStr.gbr_none)$($TK.R)"; return }
    $branches = @(git branch --all --format='%(refname:short)' | Where-Object { $_ -and $_ -notmatch '/HEAD$' })
    $pick = Invoke-Fzf $branches @('--height=60%', "--header=$($TkStr.gbr_header)", '--prompt=branch ❯ ', '--preview=git log --oneline --color=always -25 {}', '--preview-window=right:55%')
    if ($pick) { git checkout ($pick -replace '^origin/', '') }
}

function global:o { param([string]$Path = '.') Invoke-Item -LiteralPath $Path }

# ── kubernetes: switch context / namespace, the prompt picks it up by itself ─
function global:kctx([string]$Name) {
    if (-not (Find-TkCommand kubectl)) { Write-Host "  $($TK.dim)$($TkStr.k8s_missing)$($TK.R)"; return }
    if (-not $Name) {
        $list = @(Invoke-WithTimeout kubectl @('config', 'get-contexts', '-o', 'name') 5000 | Where-Object { $_ })
        if (-not $list) { Write-Host "  $($TK.dim)$($TkStr.k8s_none)$($TK.R)"; return }
        $Name = Invoke-Fzf $list @('--height=40%', "--header=$($TkStr.kctx_header)", '--prompt=context ❯ ', '--preview=kubectl config get-contexts {}', '--preview-window=down:3:wrap')
    }
    if ($Name) { kubectl config use-context $Name }
}

function global:kns([string]$Name) {
    if (-not (Find-TkCommand kubectl)) { Write-Host "  $($TK.dim)$($TkStr.k8s_missing)$($TK.R)"; return }
    if (-not $Name) {
        $list = @(Invoke-WithTimeout kubectl @('get', 'namespaces', '-o', 'name') 8000 | ForEach-Object { $_ -replace '^namespace/', '' } | Where-Object { $_ })
        if (-not $list) { Write-Host "  $($TK.dim)$($TkStr.kns_none)$($TK.R)"; return }
        $Name = Invoke-Fzf $list @('--height=40%', "--header=$($TkStr.kns_header)", '--prompt=namespace ❯ ')
    }
    if ($Name) { kubectl config set-context --current --namespace $Name }
}

# ── small helpers, same names as on the server ───────────────────────────────
function global:ex([string]$Archive) {
    if (-not (Test-Path -LiteralPath $Archive)) { Write-Host "  $($TK.err)$($TkStr.ex_nofile -f $Archive)$($TK.R)"; return }
    $file = Get-Item -LiteralPath $Archive
    $name = $file.Name -replace '\.(tar\.(gz|xz|bz2|zst)|tgz|txz|zip|7z|tar|rar)$', ''
    $dest = Join-Path $file.DirectoryName $name
    if ($file.Name -notmatch '\.(tar\.(gz|xz|bz2|zst)|tgz|txz|zip|7z|tar)$') { Write-Host "  $($TK.err)$($TkStr.ex_unknown -f $file.Name)$($TK.R)"; return }
    New-Item -ItemType Directory -Force $dest | Out-Null
    tar -xf $file.FullName -C $dest
    if ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)✓ $($TkStr.ex_done -f $dest)$($TK.R)" }
}

function global:bak {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach ($f in $args) {
        if (-not (Test-Path -LiteralPath $f)) { Write-Host "  $($TK.err)$($TkStr.ex_nofile -f $f)$($TK.R)"; continue }
        Copy-Item -LiteralPath $f "$f.bak-$stamp" -Recurse
        Write-Host "  → $f.bak-$stamp"
    }
}

function global:psg([string]$Name) {
    Get-Process | Where-Object { $_.ProcessName -like "*$Name*" } | Sort-Object WorkingSet64 -Descending |
        Select-Object Id, @{ N = 'Memory'; E = { Format-TkSize $_.WorkingSet64 } }, @{ N = 'CPU(s)'; E = { [math]::Round($_.CPU, 1) } }, ProcessName, @{ N = 'Path'; E = { $_.Path } } |
        Format-Table -AutoSize
}

function global:cb {
    $lines = @($input | ForEach-Object { "$_" -replace "`e\[[0-9;]*m", '' })
    if (-not $lines) { Get-Clipboard; return }
    $lines | Set-Clipboard
    Write-Host ("  {0}{1}{2}" -f $TK.dim, ($TkStr.cb_done -f $lines.Count), $TK.R)
}

# ── my config / doctor / update ──────────────────────────────────────────────
function global:Get-ConfigLocations {
    $wt = Get-TerminalSettingsPaths | Select-Object -First 1
    [ordered]@{
        profile     = $global:ProfileDir
        custom      = Join-Path $global:ProfileDir 'custom.ps1'
        bin         = Join-Path $global:ProfileDir 'bin'
        srvcustom   = Join-Path $global:ProfileDir 'server\custom'
        settings    = Join-Path $HOME '.config\termistry'
        completions = Join-Path $HOME '.cache\pwsh-completions'
        predictor   = Join-Path $HOME '.cache\pwsh-predictor'
        wt          = $(if ($wt) { $wt } else { Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' })
        vscode      = Join-Path $env:APPDATA 'Code\User\settings.json'
        gitconfig   = Join-Path $HOME '.gitconfig'
        ssh         = Join-Path $HOME '.ssh\config'
    }
}

function global:Show-MyConfig {
    Write-TkTitle $TkStr.config_title $TkStr.config_hint
    $loc = Get-ConfigLocations
    $rows = foreach ($k in $loc.Keys) {
        [pscustomobject]@{ What = $TkStr.config_rows[$k]; Path = $loc[$k].Replace($HOME, '~'); State = $(if (Test-Path -LiteralPath $loc[$k]) { '✓' } else { $TkStr.config_missing }) }
    }
    Write-TkTable $rows @(
        @{ N = ' '; P = 'State'; C = { param($r) if ($r.State -eq '✓') { 'ok' } else { 'dim' } } }
        @{ N = ''; P = 'What'; C = 'text' }
        @{ N = ''; P = 'Path'; C = 'cmd' }
    )
    Write-Host ''
}

function global:doctor {
    Write-TkTitle $TkStr.doctor_title ($TkStr.doctor_hint -f $global:TermistryVersion)
    $state = @{ problems = 0 }
    $check = { param($ok, $label, $detail) if ($ok) { Write-Host "  $($TK.ok)✓$($TK.R) $label $($TK.dim)$detail$($TK.R)" } else { $state.problems++; Write-Host "  $($TK.err)✗$($TK.R) $label $($TK.dim)$detail$($TK.R)" } }

    $tools = 'git', 'fzf', 'zoxide', 'eza', 'bat', 'rg', 'fd', 'delta', 'lazygit', 'tldr', 'gh'
    $missing = @($tools | Where-Object { -not (Find-TkCommand $_) })
    & $check (-not $missing) $TkStr.doctor_tools $(if ($missing) { $TkStr.doctor_missing -f ($missing -join ', ') } else { $tools -join ' ' })

    $lost = @($global:TsFiles | Where-Object { -not (Test-Path (Join-Path $global:ProfileDir $_)) })
    & $check (-not $lost) $TkStr.doctor_files $(if ($lost) { $TkStr.doctor_missing -f ($lost -join ', ') } else { $global:ProfileDir.Replace($HOME, '~') })

    & $check (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-Regular.ttf") $TkStr.doctor_font 'JetBrainsMono NF'

    $wtOk = $false
    foreach ($path in Get-TerminalSettingsPaths) {
        try { $s = Get-Content $path -Raw | ConvertFrom-Json; $wtOk = ($s.schemes.name -contains $Themes[$global:ThemeName].title) -and ($s.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') } catch {}
    }
    & $check $wtOk $TkStr.doctor_wt ''
    & $check ([bool](Get-Module -ListAvailable PSFzf)) $TkStr.doctor_psfzf 'Ctrl+R · Ctrl+T'
    if ($global:isInteractive) {
        $pred = (Get-PSSubsystem -Kind CommandPredictor).Implementations | Where-Object Name -eq 'History'
        & $check ([bool]$pred) $TkStr.doctor_predictor ''
    }

    $customFile = Join-Path $global:ProfileDir 'custom.ps1'
    $customOk = $true; $detail = ''
    if (Test-Path $customFile) {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($customFile, [ref]$null, [ref]$errors)
        if ($errors) { $customOk = $false; $detail = "$($errors[0].Extent.StartLineNumber): $($errors[0].Message)" }
    }
    & $check $customOk $TkStr.doctor_custom $detail

    $ms = [int](Measure-Command { & (Get-Process -Id $PID).Path -NoLogo -Command 'exit' }).TotalMilliseconds
    & $check ($ms -lt 3500) $TkStr.doctor_startup "$ms ms"

    Write-Host ''
    if ($state.problems) { Write-Host "  $($TK.warn)$($TkStr.doctor_fix)$($TK.R)" } else { Write-Host "  $($TK.ok)$($TkStr.doctor_ok)$($TK.R)" }
    Write-Host ''
}

function global:update {
    Write-Host "  $($TK.dim)$($TkStr.update_start)$($TK.R)"
    try { $installer = Invoke-RestMethod 'https://raw.githubusercontent.com/Ange1oc/termistry/master/install.ps1' -TimeoutSec 20 }
    catch { Write-Host "  $($TK.err)$($TkStr.update_fail -f $_.Exception.Message)$($TK.R)"; return }
    & ([scriptblock]::Create($installer)) -Lang $global:LangName
    Write-Host "  $($TK.ok)$($TkStr.update_done)$($TK.R)"
}

$global:CompletionGenerators = [ordered]@{
    kubectl  = { kubectl completion powershell }
    helm     = { helm completion powershell }
    kind     = { kind completion powershell }
    k3d      = { k3d completion powershell }
    minikube = { minikube completion powershell }
    docker   = { docker completion powershell }
    gh       = { gh completion -s powershell }
}
# Cobra completion scripts define helper functions without a scope; they are loaded from inside
# a function, so the definitions are rewritten to global: and the file gets a marker line.
function global:Update-Completions {
    $dir = "$HOME\.cache\pwsh-completions"
    New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($name in $global:CompletionGenerators.Keys) {
        $file = Join-Path $dir "$name.ps1"
        if (Find-TkCommand $name) {
            $text = (& $global:CompletionGenerators[$name] | Out-String)
            $text = [regex]::Replace($text, '(?m)^(\s*)(function|filter)\s+(?!global:)(\S+)', '$1$2 global:$3')
            Set-Content $file ("# global`n" + $text) -Encoding utf8
            Write-Host "  ✓ $name" -ForegroundColor Green
        } elseif (Test-Path $file) {
            Remove-Item $file
        }
    }
}