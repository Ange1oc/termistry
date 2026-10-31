# Workspace: the projects you work on, as a short list next to the prompt rather than an index of the disk.
# ~/.config/termistry/projects.tsv holds "path<TAB>flags<TAB>types" (flag: pin) and projects-ssh.tsv holds
# "path<TAB>environment<TAB>ssh host<TAB>remote folder". The prompt reads the first one (prompt.ps1), this file
# changes them. Recently used projects come from zoxide, which already records every folder you visit.
$global:TsProjectSshFile = Join-Path $HOME '.config\termistry\projects-ssh.tsv'

# Every change re-reads the file under a lock and replaces it in one move: sessions editing the list at the
# same time do not lose each other's changes, and a reader never sees half a file.
function global:Edit-TsList([string]$File, [scriptblock]$Change) {
    New-Item -ItemType Directory -Force (Split-Path $File) | Out-Null
    $lock = $null
    for ($try = 0; -not $lock; $try++) {
        try { $lock = [IO.File]::Open("$File.lock", 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException], [UnauthorizedAccessException] { if ($try -ge 250) { throw }; Start-Sleep -Milliseconds 20 }
    }
    try {
        $lines = [Collections.Generic.List[string]]::new()
        if ([IO.File]::Exists($File)) { $lines.AddRange([IO.File]::ReadAllLines($File)) }
        & $Change $lines
        $tmp = "$File.$PID.tmp"
        [IO.File]::WriteAllLines($tmp, $lines, [Text.UTF8Encoding]::new($false))
        for ($try = 0; ; $try++) {
            try { [IO.File]::Move($tmp, $File, $true); break }
            catch [IO.IOException], [UnauthorizedAccessException] { if ($try -ge 100) { [IO.File]::Delete($tmp); throw }; Start-Sleep -Milliseconds 20 }
        }
    } finally {
        $lock.Dispose()
        # fails harmlessly while another session holds it; the last one out removes it
        try { [IO.File]::Delete("$File.lock") } catch {}
    }
    $global:TsProjects.Checked = [datetime]::MinValue
}

function global:Find-TsLine($Lines, [string]$Path) {
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $l = $Lines[$i]
        if ($l.StartsWith($Path, [StringComparison]::OrdinalIgnoreCase) -and ($l.Length -eq $Path.Length -or $l[$Path.Length] -eq "`t")) { return $i }
    }
    -1
}

# Adds projects or updates them. Pin: $true / $false, or $null to keep. Returns how many were new.
function global:Set-TsProject([object[]]$Projects, $Pin = $null) {
    $state = @{ New = 0 }
    Edit-TsList $global:TsProjectsFile {
        param($lines)
        foreach ($p in $Projects) {
            $i = Find-TsLine $lines $p.Path
            $old = if ($i -ge 0) { $lines[$i].Split("`t") } else { @() }
            $flags = if ($null -ne $Pin) { if ($Pin) { 'pin' } else { '' } } elseif ($old.Count -gt 1) { $old[1] } else { '' }
            $types = if ($p.Types) { $p.Types } elseif ($old.Count -gt 2) { $old[2] } else { '' }
            $line = "$($p.Path)`t$flags`t$types"
            if ($i -ge 0) { $lines[$i] = $line } else { $lines.Add($line); $state.New++ }
        }
    }
    $state.New
}

function global:Remove-TsProject([string[]]$Paths) {
    foreach ($file in $global:TsProjectsFile, $global:TsProjectSshFile) {
        if (-not [IO.File]::Exists($file)) { continue }
        Edit-TsList $file {
            param($lines)
            foreach ($p in $Paths) { for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].Split("`t")[0] -eq $p) { $lines.RemoveAt($i) } } }
        }
    }
}

# The names of a folder's entries in one directory listing, which is far cheaper than a check per marker
function global:Get-TsFolderEntries([string]$Dir) {
    $opts = [IO.EnumerationOptions]@{ IgnoreInaccessible = $true; AttributesToSkip = 0 }
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $subs = [Collections.Generic.List[string]]::new()
    foreach ($e in [IO.DirectoryInfo]::new($Dir).EnumerateFileSystemInfos('*', $opts)) {
        [void]$names.Add($e.Name)
        if ($e.Attributes -band [IO.FileAttributes]::Directory) { $subs.Add($e.Name) }
    }
    @{ Names = $names; Dirs = $subs }
}

function global:Get-TsTypes($Names) {
    $types = [Collections.Generic.List[string]]::new()
    foreach ($m in $global:ProjectMarkers.GetEnumerator()) { if ($Names.Contains($m.Key) -and -not $types.Contains($m.Value)) { $types.Add($m.Value) } }
    $types -join ','
}

function global:Get-TsProjectInfo([string]$Path) {
    $types = if (Test-TsNetworkPath $Path) { '' } else { try { Get-TsTypes (Get-TsFolderEntries $Path).Names } catch { '' } }
    @{ Path = $Path; Types = $types }
}

# Project folders under a folder: a folder with .git or a marker file is a project and is not looked into;
# hidden folders and build or dependency folders are skipped. Breadth-first, a few levels, one listing per folder.
function global:Find-TsProjectFolders([string]$Folder, [int]$Depth = 3) {
    $skip = [Collections.Generic.HashSet[string]]::new([string[]]('node_modules', 'vendor', 'target', 'bin', 'obj', 'dist', 'build', 'out', 'venv', '__pycache__'), [StringComparer]::OrdinalIgnoreCase)
    $queue = [Collections.Generic.Queue[object]]::new()
    $queue.Enqueue(@($Folder, 0))
    $visited = 0
    while ($queue.Count -and $visited -lt 50000) {
        $dir, $level = $queue.Dequeue()
        $visited++
        try { $e = Get-TsFolderEntries $dir } catch { continue }
        $types = Get-TsTypes $e.Names
        if ($types -or $e.Names.Contains('.git')) { @{ Path = $dir; Types = $types }; continue }
        if ($level -ge $Depth) { continue }
        foreach ($s in $e.Dirs) { if ($s[0] -ne '.' -and -not $skip.Contains($s)) { $queue.Enqueue(@([IO.Path]::Combine($dir, $s), ($level + 1))) } }
    }
}

# Projects among the folders zoxide remembers: no disk scan, only places you have been
function global:Find-TsVisitedProjects {
    if (-not (Find-TkCommand zoxide)) { return }
    $exit = $global:LASTEXITCODE
    $dirs = @(zoxide query --list 2>$null)
    $global:LASTEXITCODE = $exit
    $seen = @{}
    foreach ($d in $dirs) {
        if (-not $d -or (Test-TsNetworkPath $d) -or -not [IO.Directory]::Exists($d)) { continue }
        $root = Get-TsGitRoot $d
        if (-not $root) {
            try { $names = (Get-TsFolderEntries $d).Names } catch { continue }
            if (-not (Get-TsTypes $names)) { continue }
            $root = $d
        }
        if (-not $seen.ContainsKey($root)) { $seen[$root] = $true; Get-TsProjectInfo $root }
    }
}

# zoxide's score of each listed project: visits to the project and to any folder inside it add up
function global:Get-TsProjectScores($Map) {
    $scores = @{}
    if (-not (Find-TkCommand zoxide)) { return $scores }
    $exit = $global:LASTEXITCODE
    $out = @(zoxide query --list --score 2>$null)
    $global:LASTEXITCODE = $exit
    $inv = [Globalization.CultureInfo]::InvariantCulture
    foreach ($line in $out) {
        $t = $line.TrimStart(); $sp = $t.IndexOf(' ')
        $score = 0.0
        if ($sp -lt 1 -or -not [double]::TryParse($t.Substring(0, $sp), [Globalization.NumberStyles]::Float, $inv, [ref]$score)) { continue }
        $p = Find-TsProject $t.Substring($sp + 1) $Map
        if ($p) { $scores[$p] = [double]$scores[$p] + $score }
    }
    $scores
}

function global:Read-TsProjectSsh {
    if (-not [IO.File]::Exists($global:TsProjectSshFile)) { return }
    foreach ($line in [IO.File]::ReadAllLines($global:TsProjectSshFile)) {
        $f = $line.Split("`t")
        if ($f.Count -lt 3 -or $line[0] -eq '#') { continue }
        [pscustomobject]@{ Path = $f[0]; Env = $f[1]; Host = $f[2]; Dir = $(if ($f.Count -gt 3) { $f[3] } else { '' }) }
    }
}

# Lines for the picker: pinned first, then by zoxide score, then by name; the full path after a TAB
function global:Get-TsWorkLines {
    $map = Read-TsProjects -Force
    if (-not $map -or -not $map.Count) { return }
    $scores = Get-TsProjectScores $map
    $links = @{}
    foreach ($l in Read-TsProjectSsh) { $links[$l.Path] = @($links[$l.Path]) + $l.Env | Where-Object { $_ } }
    $keyed = [Collections.Generic.List[string]]::new($map.Count)
    foreach ($kv in $map.GetEnumerator()) {
        $path = $kv.Key; $v = $kv.Value
        $tab = $v.IndexOf("`t")
        $pin = $v.StartsWith('pin')
        $types = if ($tab -ge 0) { $v.Substring($tab + 1) } else { '' }
        $name = [IO.Path]::GetFileName($path); if (-not $name) { $name = $path }
        $rank = [long](1e12 - [math]::Min(1e12 - 1, 100 * [double]$scores[$path]))
        $mark = if ($pin) { "$($TK.warn)$([char]0xF005)$($TK.R)" } else { ' ' }
        $ssh = if ($links.ContainsKey($path)) { "  $($TK.teal)$([char]0xF233) $($links[$path] -join ' ')$($TK.R)" } else { '' }
        $shown = $path.Replace($HOME, '~')
        $keyed.Add("$(if ($pin) { 0 } else { 1 })$($rank.ToString('D13'))$($name.ToLowerInvariant())`n$mark $($TK.text)$($name.PadRight(24))$($TK.R) $($TK.dim)$($types.PadRight(14)) $shown$($TK.R)$ssh`t$path")
    }
    $keyed.Sort([StringComparer]::Ordinal)
    foreach ($k in $keyed) { $k.Substring($k.IndexOf("`n") + 1) }
}

# The project a folder belongs to: the listed project it is in, else its git root or marker folder, else the folder
function global:Resolve-TsProjectPath([string]$Dir) {
    $map = Read-TsProjects -Force
    $listed = if ($map) { Find-TsProject $Dir $map } else { '' }
    if ($listed) { return $listed }
    $ctx = Get-TsContext $Dir
    if ($ctx.Project) { $ctx.Project } else { $Dir }
}

# A project named on the command line: a path, or the folder name of a listed project; nothing means here
function global:Resolve-TsProjectArg([string]$Arg) {
    if (-not $Arg) { return Resolve-TsProjectPath $PWD.ProviderPath }
    if (Test-Path -LiteralPath $Arg -PathType Container) {
        $full = (Resolve-Path -LiteralPath $Arg).ProviderPath.TrimEnd('\'); if ($full -match '^[A-Za-z]:$') { $full += '\' }
        return $full
    }
    $map = Read-TsProjects -Force
    $hits = @(if ($map) { $map.Keys | Where-Object { [IO.Path]::GetFileName($_) -eq $Arg } })
    if ($hits.Count -eq 1) { return $hits[0] }
    if ($hits.Count -gt 1) { Write-Host "  $($TK.err)$($TkStr.work_ambiguous -f $Arg)$($TK.R)"; $hits | ForEach-Object { Write-Host "    $($TK.dim)$_$($TK.R)" } }
    else { Write-Host "  $($TK.err)$($TkStr.work_unknown -f $Arg)$($TK.R)" }
}

# cd into the remote folder, then the login shell. The folder is single-quoted for the remote shell, so nothing
# in it is expanded or run; a leading ~/ stays outside the quotes and still means the home folder.
function global:ConvertTo-TsRemoteCommand([string]$Dir) {
    if (-not $Dir) { return '' }
    if ($Dir -eq '~') { return 'cd && exec $SHELL -l' }
    $tilde = ''
    if ($Dir.StartsWith('~/')) { $tilde = '~/'; $Dir = $Dir.Substring(2) }
    "cd -- $tilde'$($Dir.Replace("'", "'\''"))' && exec `$SHELL -l"
}

function global:Connect-TsProjectSsh([string]$Path, [string]$Env) {
    $links = @(Read-TsProjectSsh | Where-Object Path -eq $Path)
    if (-not $links) { Write-Host "  $($TK.dim)$($TkStr.work_ssh_none -f [IO.Path]::GetFileName($Path))$($TK.R)"; return }
    $link = if ($Env) { $links | Where-Object Env -eq $Env | Select-Object -First 1 } elseif ($links.Count -eq 1) { $links[0] }
    if (-not $link -and $Env) { Write-Host "  $($TK.err)$($TkStr.work_ssh_unknown -f $Env, ($links.Env -join ', '))$($TK.R)"; return }
    if (-not $link) {
        $pick = @(Invoke-Fzf ($links | ForEach-Object { "{0,-12} {1}{2}" -f $_.Env, $_.Host, $(if ($_.Dir) { ":$($_.Dir)" }) }) @('--height=12', "--header=$($TkStr.work_ssh_header)", '--prompt=ssh ❯ '))
        if (-not $pick) { return }
        $link = $links | Where-Object Env -eq ($pick[0] -split '\s+')[0] | Select-Object -First 1
    }
    $remote = ConvertTo-TsRemoteCommand $link.Dir
    Write-Host ("  {0}→ ssh {1}{2}{3}" -f $TK.dim, $link.Host, $(if ($link.Dir) { "  cd $($link.Dir)" }), $TK.R)
    if ($remote) { ssh -t $link.Host $remote } else { ssh $link.Host }
}

function global:Invoke-TsWorkSsh([string[]]$Words) {
    $verb = if ($Words) { $Words[0] } else { '' }
    if ($verb -eq 'add') {
        $envName, $sshHost, $dir = $Words[1], $Words[2], (@($Words | Select-Object -Skip 3) -join ' ')
        if ($envName -notmatch '^[A-Za-z0-9_-]{1,20}$') { Write-Host "  $($TK.err)$($TkStr.work_ssh_bad_env)$($TK.R)"; return }
        if ($sshHost -notmatch '^[A-Za-z0-9_.@][A-Za-z0-9_.@-]*$') { Write-Host "  $($TK.err)$($TkStr.work_ssh_bad_host)$($TK.R)"; return }
        if ($dir -match '[\x00-\x1f]') { Write-Host "  $($TK.err)$($TkStr.work_ssh_bad_dir)$($TK.R)"; return }
        $path = Resolve-TsProjectPath $PWD.ProviderPath
        $map = Read-TsProjects -Force
        if (-not $map -or -not $map.ContainsKey($path)) { $null = Set-TsProject @(Get-TsProjectInfo $path) }
        Edit-TsList $global:TsProjectSshFile {
            param($lines)
            for ($i = $lines.Count - 1; $i -ge 0; $i--) { $f = $lines[$i].Split("`t"); if ($f[0] -eq $path -and $f[1] -eq $envName) { $lines.RemoveAt($i) } }
            $lines.Add("$path`t$envName`t$sshHost`t$dir")
        }
        if ($sshHost -notin @((Get-SshHost).Name) -and $sshHost -notmatch '@') { Write-Host "  $($TK.warn)$($TkStr.work_ssh_not_in_config -f $sshHost)$($TK.R)" }
        Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_ssh_added -f $envName, [IO.Path]::GetFileName($path), "$sshHost$(if ($dir) { ":$dir" })")"
        return
    }
    if ($verb -eq 'rm') {
        $path = Resolve-TsProjectPath $PWD.ProviderPath
        $state = @{ Removed = 0 }
        if ([IO.File]::Exists($global:TsProjectSshFile)) {
            Edit-TsList $global:TsProjectSshFile {
                param($lines)
                for ($i = $lines.Count - 1; $i -ge 0; $i--) { $f = $lines[$i].Split("`t"); if ($f[0] -eq $path -and $f[1] -eq $Words[1]) { $lines.RemoveAt($i); $state.Removed++ } }
            }
        }
        if ($state.Removed) { Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_ssh_removed -f $Words[1])" }
        else { Write-Host "  $($TK.err)$($TkStr.work_ssh_unknown -f $Words[1], '-')$($TK.R)" }
        return
    }
    Connect-TsProjectSsh (Resolve-TsProjectPath $PWD.ProviderPath) $verb
}

function global:Show-TsWorkInfo {
    $dir = $PWD.ProviderPath
    $ctx = Get-TsContext $dir
    $path = Resolve-TsProjectPath $dir
    $map = Read-TsProjects -Force
    $listed = $map -and $map.ContainsKey($path)
    $types = if ($listed) { $map[$path].Split("`t")[1] } else { '' }
    if (-not $types) { $types = (Get-TsProjectInfo $path).Types }
    Write-TkTitle ($TkStr.work_info_title -f [IO.Path]::GetFileName($path)) $path.Replace($HOME, '~')
    $state = if (-not $listed) { $TkStr.work_state_new } elseif ($map[$path].StartsWith('pin')) { $TkStr.work_state_pinned } else { $TkStr.work_state_listed }
    Write-TkRow $TkStr.work_info_list $state
    Write-TkRow $TkStr.work_info_types $(if ($types) { $types } else { '-' })
    if ($ctx.Root) { Write-TkRow 'git' (Get-TsGitBranch $ctx.Root) }
    $links = @(Read-TsProjectSsh | Where-Object Path -eq $path)
    Write-TkRow 'ssh' $(if ($links) { ($links | ForEach-Object { "$($_.Env) → $($_.Host)$(if ($_.Dir) { ":$($_.Dir)" })" }) -join ' · ' } else { $TkStr.work_info_no_ssh })
    Write-Host ''
}

function global:Show-TsWorkList {
    $map = Read-TsProjects -Force
    if (-not $map -or -not $map.Count) { Write-Host "  $($TK.dim)$($TkStr.work_empty)$($TK.R)"; return }
    Write-TkTitle $TkStr.work_list_title ($TkStr.work_list_hint -f $map.Count)
    $rows = foreach ($kv in $map.GetEnumerator()) {
        $f = $kv.Value.Split("`t")
        [pscustomobject]@{ Pin = $(if ($f[0] -eq 'pin') { [string][char]0xF005 } else { ' ' }); Name = [IO.Path]::GetFileName($kv.Key); Types = $(if ($f.Count -gt 1) { $f[1] }); Path = $kv.Key.Replace($HOME, '~') }
    }
    Write-TkTable @($rows | Sort-Object { $_.Pin -eq ' ' }, Name) @(
        @{ N = ' '; P = 'Pin'; C = 'warn' }
        @{ N = ''; P = 'Name'; C = 'text' }
        @{ N = ''; P = 'Types'; C = 'dim' }
        @{ N = ''; P = 'Path'; C = 'cmd' }
    )
    Write-Host ''
}

# Forgets projects whose folder is gone. A folder whose parent is missing too (a drive or share that is not
# connected right now) is kept: it may come back.
function global:Clear-TsWorkList {
    $map = Read-TsProjects -Force
    $gone = @(if ($map) { $map.Keys | Where-Object { -not [IO.Directory]::Exists($_) -and [IO.Directory]::Exists([IO.Path]::GetDirectoryName($_)) } })
    if (-not $gone) { Write-Host "  $($TK.dim)$($TkStr.work_clean_none)$($TK.R)"; return }
    Remove-TsProject $gone
    foreach ($p in $gone) { Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_removed -f $p.Replace($HOME, '~'))" }
}

function global:Import-TsProjects([string]$Folder, [int]$Depth) {
    $map = Read-TsProjects -Force
    $found = if ($Folder) {
        if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { Write-Host "  $($TK.err)$($TkStr.ex_nofile -f $Folder)$($TK.R)"; return }
        $full = (Resolve-Path -LiteralPath $Folder).ProviderPath
        Write-Host "  $($TK.dim)$($TkStr.work_import_scan -f $full.Replace($HOME, '~'))$($TK.R)"
        @(Find-TsProjectFolders $full $Depth)
    } else { @(Find-TsVisitedProjects) }
    $new = @($found | Where-Object { -not $map -or -not $map.ContainsKey($_.Path) })
    if (-not $new) { Write-Host "  $($TK.dim)$($TkStr.work_import_none)$($TK.R)"; return }
    $byPath = @{}; foreach ($p in $new) { $byPath[$p.Path] = $p }
    $lines = $new | ForEach-Object { "{0} {1}{2}{3} {4}{5}{6}`t{7}" -f ([IO.Path]::GetFileName($_.Path)).PadRight(24), $TK.dim, $_.Types.PadRight(14), $TK.R, $TK.cmd, $_.Path.Replace($HOME, '~'), $TK.R, $_.Path }
    $picked = Invoke-Fzf $lines @('--multi', '--ansi', "--delimiter=`t", '--with-nth=1', '--height=70%', '--bind=ctrl-a:select-all',
        "--header=$($TkStr.work_import_header -f $new.Count)", '--prompt=import ❯ ', "--preview=$(Get-TsPreview) {2}", '--preview-window=right:45%')
    $chosen = @($picked | Where-Object { $_ } | ForEach-Object { $byPath[($_ -split "`t")[1]] } | Where-Object { $_ })
    if (-not $chosen) { return }
    $added = Set-TsProject $chosen
    Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_import_done -f $added)"
}

function global:Invoke-TsWorkPicker([string]$Query) {
    if (-not (Find-TkCommand fzf)) { Show-TsWorkList; return }
    $first = $true
    while ($true) {
        $lines = @(Get-TsWorkLines)
        if (-not $lines) { Write-Host "  $($TK.dim)$($TkStr.work_empty)$($TK.R)"; return }
        $fzfArgs = @('--ansi', '--expect=ctrl-o,ctrl-p,ctrl-s,ctrl-d', "--delimiter=`t", '--with-nth=1', '--height=60%', "--query=$Query",
            "--header=$($TkStr.work_header)", '--prompt=work ❯ ', "--preview=$(Get-TsPreview) {2}", '--preview-window=right:45%')
        # work <name>: a single match goes straight there, but only on the first round
        if ($first -and $Query) { $fzfArgs += '--select-1' }
        $out = @(Invoke-Fzf $lines $fzfArgs)
        $first = $false
        if ($out.Count -lt 2) { return }
        $path = ($out[1] -split "`t")[1]
        switch ($out[0]) {
            'ctrl-p' { $null = Set-TsProject @(@{ Path = $path }) (-not (Read-TsProjects -Force)[$path].StartsWith('pin')) }
            'ctrl-d' { Remove-TsProject @($path); Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_removed -f $path.Replace($HOME, '~'))" }
            'ctrl-o' { Open-TsFile $path; return }
            'ctrl-s' { Connect-TsProjectSsh $path ''; return }
            default {
                if ([IO.Directory]::Exists($path)) { Set-Location -LiteralPath $path }
                else { Write-Host "  $($TK.err)$($TkStr.work_gone -f $path)$($TK.R)" }
                return
            }
        }
    }
}

function global:work {
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({ param($c, $p, $word) @('add', 'pin', 'unpin', 'rm', 'list', 'import', 'clean', 'ssh', 'help', '.') | Where-Object { $_ -like "$word*" } })]
        [string]$Action = '',
        [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest = @(),
        [int]$Depth = 3
    )
    $arg = if ($Rest) { $Rest[0] } else { '' }
    switch ($Action) {
        '' { Invoke-TsWorkPicker ''; return }
        'help' { help work; return }
        '.' { Show-TsWorkInfo; return }
        'list' { Show-TsWorkList; return }
        'clean' { Clear-TsWorkList; return }
        'import' { Import-TsProjects $arg $Depth; return }
        'ssh' { Invoke-TsWorkSsh $Rest; return }
        'add' {
            $path = if ($arg) { Resolve-TsProjectArg $arg } else { Resolve-TsProjectPath $PWD.ProviderPath }
            if (-not $path) { return }
            $added = Set-TsProject @(Get-TsProjectInfo $path)
            Write-Host "  $($TK.ok)✓$($TK.R) $($(if ($added) { $TkStr.work_added } else { $TkStr.work_exists }) -f $path.Replace($HOME, '~'))"
            return
        }
        { $_ -in 'pin', 'unpin' } {
            $path = Resolve-TsProjectArg $arg
            if (-not $path) { return }
            $map = Read-TsProjects -Force
            $info = if ($map -and $map.ContainsKey($path)) { @{ Path = $path } } else { Get-TsProjectInfo $path }
            $null = Set-TsProject @($info) ($Action -eq 'pin')
            Write-Host "  $($TK.ok)✓$($TK.R) $($(if ($Action -eq 'pin') { $TkStr.work_pinned } else { $TkStr.work_unpinned }) -f $path.Replace($HOME, '~'))"
            return
        }
        'rm' {
            $path = Resolve-TsProjectArg $arg
            if (-not $path) { return }
            $map = Read-TsProjects -Force
            if (-not $map -or -not $map.ContainsKey($path)) { Write-Host "  $($TK.err)$($TkStr.work_unknown -f $path.Replace($HOME, '~'))$($TK.R)"; return }
            Remove-TsProject @($path)
            Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.work_removed -f $path.Replace($HOME, '~'))"
            return
        }
        default { Invoke-TsWorkPicker ((@($Action) + $Rest) -join ' ') }
    }
}
