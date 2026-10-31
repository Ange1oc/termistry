<#
.SYNOPSIS
  Records docs\demo.gif from a real Windows Terminal window running the profile from src\.
  The shell runs in a sandbox home with a demo project, demo history and demo ssh hosts, so nothing personal
  shows up. The shell plays the session below itself: a background thread writes key events into its own
  console input, so PSReadLine and fzf get real keystrokes and nothing is sent to other windows. Frames are
  rendered from the window itself and frames-to-gif.py (run with uv) assembles the GIF. `theme` edits the Windows
  Terminal settings, so they are restored afterwards. The window may be covered but not minimized (about a minute).

.EXAMPLE
  .\tools\record-demo.ps1                      # the tour → docs\demo.gif
.EXAMPLE
  .\tools\record-demo.ps1 -Session workspace   # projects and work → docs\workspace.gif
#>
param([ValidateSet('tour', 'workspace')][string]$Session = 'tour', [string]$OutFile = '', [int]$Columns = 120, [int]$Rows = 32, [int]$Width = 1100)
$ErrorActionPreference = 'Stop'
if (-not $OutFile) { $OutFile = Join-Path $PSScriptRoot "..\docs\$(if ($Session -eq 'tour') { 'demo' } else { 'workspace' }).gif" }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Public, not %TEMP%: paths some commands print must not carry the user name
$work = Join-Path $env:PUBLIC 'termistry-demo'
$sandbox = Join-Path $work 'home'
$frames = Join-Path $work 'frames'
$title = 'Termistry demo'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
$profileDir = Join-Path $sandbox 'Documents\PowerShell'
New-Item -ItemType Directory -Force "$profileDir\bin", "$profileDir\server", "$sandbox\.config\termistry", "$sandbox\.ssh", $frames | Out-Null
Copy-Item "$root\src\profile\*" $profileDir -Recurse
Copy-Item "$root\src\server\*" "$profileDir\server" -Recurse
Set-Content "$sandbox\.config\termistry\lang" 'en'
Set-Content "$sandbox\.config\termistry\theme" 'mocha'

# The sessions: sleep <seconds> · type <text> · key <name> [times] (Enter, Tab, Esc, Backspace, Up, Down, Left, Right, F1, Ctrl+R, Ctrl+A, Alt+C)
$sessions = @{}
$sessions.workspace = @'
sleep 2
type work .
key Enter
sleep 3.5
type work
key Enter
sleep 3
type api
sleep 1.5
key Enter
sleep 2
type work pin
key Enter
sleep 2
type cd ..
key Enter
sleep 1
type work import .
key Enter
sleep 3
key Ctrl+A
sleep 1.2
key Enter
sleep 2
type work
key Enter
sleep 3.5
key Esc
sleep 1
type work list
key Enter
sleep 3.5
done
type exit
key Enter
'@
$sessions.tour = @'
sleep 2
type ll
key Enter
sleep 2.5
type g log --oneline -4
key Enter
sleep 2.5
type dock
sleep 2
key Down
sleep 0.8
key Down
sleep 1.2
key Backspace 30
sleep 0.6
type cls
key Enter
type theme
key Enter
sleep 3
type theme la
key Tab
sleep 0.8
key Enter
sleep 2
type help git
key Enter
sleep 3.5
key F1
sleep 1.5
type branch
sleep 2
key Esc
sleep 1
type cls
key Enter
type theme tok
key Tab
sleep 0.8
key Enter
sleep 2
key Alt+C
sleep 1.6
key Down
sleep 0.6
key Right
sleep 1.6
key Left
sleep 1
key Esc
sleep 1
type rgi listen
key Enter
sleep 2.5
key Esc
sleep 1
type gbr
key Enter
sleep 2.5
key Esc
sleep 1
key Ctrl+R
sleep 1.5
type compose
sleep 2
key Esc
sleep 1
type my ssh
key Enter
sleep 3.5
done
type exit
key Enter
'@
Set-Content "$work\steps.txt" $sessions[$Session]

@'
Host prod-1
    HostName 203.0.113.10
    User deploy
Host staging
    HostName 198.51.100.20
    User deploy
Host db-backup
    HostName 192.0.2.30
    User backup
    Port 2222
'@ | Set-Content "$sandbox\.ssh\config"

$history = Join-Path $sandbox 'history.txt'
@'
git pull --rebase
npm run dev
docker compose ps
docker compose logs -f web
docker compose up -d --build
kubectl get pods -n shop
git switch -c feature/checkout
npm test
docker compose restart worker
ssh prod-1
git push -u origin feature/checkout
'@ | Set-Content $history

$demo = Join-Path $sandbox 'code\shop'
New-Item -ItemType Directory -Force "$demo\src", "$demo\deploy", "$demo\k8s" | Out-Null
'{ "name": "shop", "version": "2.4.0", "private": true, "scripts": { "dev": "node src/index.js" } }' | Set-Content "$demo\package.json"
"import http from 'node:http';`nhttp.createServer((_, res) => res.end('ok')).listen(3000);" | Set-Content "$demo\src\index.js"
"services:`n  web:`n    build: .`n    ports: ['3000:3000']`n  db:`n    image: postgres:16" | Set-Content "$demo\docker-compose.yml"
"FROM node:24-alpine`nCOPY . .`nCMD [`"node`", `"src/index.js`"]" | Set-Content "$demo\Dockerfile"
"apiVersion: apps/v1`nkind: Deployment`nmetadata:`n  name: shop" | Set-Content "$demo\k8s\deployment.yaml"
"#!/usr/bin/env bash`nset -e`ndocker compose up -d --build" | Set-Content "$demo\deploy\release.sh"
"# shop`n" | Set-Content "$demo\README.md"
Push-Location $demo
git init -q -b main
foreach ($c in 'Initial storefront', 'Add docker compose setup', 'Add Kubernetes deployment', 'Add release script') {
    git add -A; git -c user.name=demo -c user.email= commit -q --allow-empty -m $c
}
git switch -q -c feature/checkout
"# shop`n`nOnline shop. Run: npm run dev" | Set-Content "$demo\README.md"
"export const VERSION = '2.4.0';" | Set-Content "$demo\src\version.js"
git add src/version.js
Pop-Location

if ($Session -eq 'workspace') {
    # more projects next to shop: three in the list, two for work import to find
    foreach ($p in @{ n = 'api'; f = 'go.mod' }, @{ n = 'infra'; f = 'compose.yaml' }, @{ n = 'blog'; f = 'package.json' }, @{ n = 'cli'; f = 'Cargo.toml' }) {
        $dir = Join-Path $sandbox "code\$($p.n)"
        New-Item -ItemType Directory -Force $dir | Out-Null
        '' | Set-Content (Join-Path $dir $p.f)
        git -C $dir init -q -b main
    }
    New-Item -ItemType Directory -Force "$sandbox\notes\ideas" | Out-Null
    $code = Join-Path $sandbox 'code'
    [IO.File]::WriteAllLines("$sandbox\.config\termistry\projects.tsv", [string[]]@(
        "$demo`tpin`tnode,docker", "$code\api`t`tgo", "$code\infra`t`tdocker", "$sandbox\notes\ideas`t`t"))
    [IO.File]::WriteAllLines("$sandbox\.config\termistry\projects-ssh.tsv", [string[]]@(
        "$demo`tprod`tprod-1`t/srv/shop", "$demo`tstaging`tstaging`t~/shop"))
}

@'
apiVersion: v1
kind: Config
current-context: staging
contexts:
- name: staging
  context: { cluster: staging, user: admin, namespace: shop }
clusters:
- name: staging
  cluster: { server: https://10.0.0.1 }
users:
- name: admin
  user: {}
'@ | Set-Content "$work\kubeconfig"

@'
using System;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
public static class DemoPlayer {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct KEY_EVENT_RECORD { public int KeyDown; public ushort Repeat, Vk, Scan; public char Char; public uint State; }
    [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
    struct INPUT_RECORD { [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public KEY_EVENT_RECORD Key; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sec, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool WriteConsoleInputW(IntPtr h, INPUT_RECORD[] records, uint count, out uint written);
    [DllImport("user32.dll")] static extern uint MapVirtualKeyW(uint code, uint type);
    static IntPtr conin;
    static readonly Random rnd = new Random(7);

    static void Send(ushort vk, char c, uint state) {
        var r = new INPUT_RECORD[2];
        for (int i = 0; i < 2; i++) {
            r[i].Type = 1;
            r[i].Key = new KEY_EVENT_RECORD { KeyDown = i == 0 ? 1 : 0, Repeat = 1, Vk = vk, Scan = (ushort)MapVirtualKeyW(vk, 0), Char = c, State = state };
        }
        uint written; WriteConsoleInputW(conin, r, 2, out written);
    }
    static ushort Vk(char c) {
        if (c >= 'a' && c <= 'z') return (ushort)(c - 32);
        if (c >= '0' && c <= '9') return c;
        switch (c) { case ' ': return 0x20; case '-': return 0xBD; case '.': return 0xBE; case '/': return 0xBF; default: return 0; }
    }
    static void Key(string name) {
        switch (name) {
            case "Enter": Send(0x0D, '\r', 0); break;
            case "Tab": Send(0x09, '\t', 0); break;
            case "Backspace": Send(0x08, '\b', 0); break;
            case "Esc": Send(0x1B, '\x1b', 0); break;
            case "Left": Send(0x25, '\0', 0x100); break;
            case "Up": Send(0x26, '\0', 0x100); break;
            case "Right": Send(0x27, '\0', 0x100); break;
            case "Down": Send(0x28, '\0', 0x100); break;
            case "F1": Send(0x70, '\0', 0); break;
            case "Ctrl+R": Send(0x52, '\x12', 0x08); break;
            case "Alt+C": Send(0x43, 'c', 0x02); break;
            case "Ctrl+A": Send(0x41, '\x01', 0x08); break;
            default: throw new ArgumentException(name);
        }
    }
    public static void Start(string steps, string dir) {
        conin = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        var t = new Thread(() => {
            File.WriteAllText(Path.Combine(dir, "ready"), "");
            foreach (var line in File.ReadAllLines(steps)) {
                var sp = line.IndexOf(' ');
                var cmd = sp < 0 ? line : line.Substring(0, sp);
                var arg = sp < 0 ? "" : line.Substring(sp + 1);
                if (cmd == "sleep") Thread.Sleep((int)(double.Parse(arg, CultureInfo.InvariantCulture) * 1000));
                else if (cmd == "key") {
                    var parts = arg.Split(' ');
                    int times = parts.Length > 1 ? int.Parse(parts[1]) : 1;
                    for (int i = 0; i < times; i++) { Key(parts[0]); Thread.Sleep(times > 1 ? 25 : 350); }
                }
                else if (cmd == "done") File.WriteAllText(Path.Combine(dir, "done"), "");
                else if (cmd == "type") { foreach (var c in arg) { Send(Vk(c), c, 0); Thread.Sleep(rnd.Next(45, 95)); } Thread.Sleep(300); }
            }
        });
        t.IsBackground = true;
        t.Start();
    }
}
'@ | Set-Content "$work\DemoPlayer.cs"

# The tab gets Windows Terminal's environment, not ours, so the sandbox is set up inside it
@"
`$env:USERPROFILE = '$sandbox'; `$env:HOME = '$sandbox'; `$env:APPDATA = '$sandbox\AppData\Roaming'
`$env:XDG_CONFIG_HOME = '$sandbox\.config'; `$env:KUBECONFIG = '$work\kubeconfig'; `$env:_ZO_DATA_DIR = '$sandbox\.zoxide'
Remove-Item Env:NO_COLOR -ErrorAction Ignore   # started from a tool that sets it, pwsh would strip the prompt colors
Set-Location '$demo'
"@ | Set-Content "$work\env.ps1" -Encoding utf8
@"
. '$work\env.ps1'
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -Command "[cultureinfo]::CurrentUICulture = 'en-US'; Set-PSReadLineOption -HistorySavePath '$history'; . '$profileDir\Microsoft.PowerShell_profile.ps1'; Add-Type -Path '$work\DemoPlayer.cs'; [DemoPlayer]::Start('$work\steps.txt', '$work')"
"@ | Set-Content "$work\start.ps1" -Encoding utf8
# One load beforehand fills the completion cache, so building it does not show up in the recording
"`. '$work\env.ps1'; pwsh -NoLogo -NoProfile -Command `". '$profileDir\Microsoft.PowerShell_profile.ps1'`"" | Set-Content "$work\warmup.ps1" -Encoding utf8
pwsh -NoProfile -ExecutionPolicy Bypass -File "$work\warmup.ps1" | Out-Null

# PrintWindow renders the terminal window itself, so whatever covers it on screen never ends up in a frame
@"
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class Grab { [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; } [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags); [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
[void][Grab]::SetProcessDPIAware()
`$h = [IntPtr]`$args[0]; `$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path '$work\done')) {
    `$w = New-Object Grab+RECT; [void][Grab]::GetWindowRect(`$h, [ref]`$w)
    `$v = New-Object Grab+RECT; [void][Grab]::DwmGetWindowAttribute(`$h, 9, [ref]`$v, 16)
    `$bmp = [Drawing.Bitmap]::new(`$w.R - `$w.L, `$w.B - `$w.T)
    `$g = [Drawing.Graphics]::FromImage(`$bmp); `$dc = `$g.GetHdc(); [void][Grab]::PrintWindow(`$h, `$dc, 2); `$g.ReleaseHdc(`$dc)
    `$frame = `$bmp.Clone([Drawing.Rectangle]::new(`$v.L - `$w.L, `$v.T - `$w.T, `$v.R - `$v.L, `$v.B - `$v.T), `$bmp.PixelFormat)
    `$frame.Save(('$frames\{0}.png' -f `$sw.ElapsedMilliseconds), [Drawing.Imaging.ImageFormat]::Png)
    `$frame.Dispose(); `$g.Dispose(); `$bmp.Dispose()
    Start-Sleep -Milliseconds 60
}
"@ | Set-Content "$work\capture.ps1"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class DemoWindow {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    public static IntPtr Find(string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            var c = new StringBuilder(256); var t = new StringBuilder(256);
            GetClassName(h, c, 256); GetWindowText(h, t, 256);
            if (c.ToString() == "CASCADIA_HOSTING_WINDOW_CLASS" && t.ToString().Contains(title)) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@

function Wait-For([scriptblock]$Condition, [int]$Seconds, [string]$What) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not (& $Condition)) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { throw "timed out waiting for $What" }
        Start-Sleep -Milliseconds 100
    }
}

$wtSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$wtBackup = Join-Path $work 'wt-settings.json'
Copy-Item $wtSettings $wtBackup
$capture = $null
try {
    wt.exe -w new --size "$Columns,$Rows" --pos 40,40 new-tab --title $title --suppressApplicationTitle pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$work\start.ps1"
    $hwnd = [IntPtr]::Zero
    Wait-For { ($script:hwnd = [DemoWindow]::Find($title)) -ne [IntPtr]::Zero } 15 'the Windows Terminal window'
    Wait-For { Test-Path "$work\ready" } 60 'the demo shell'
    $capture = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$work\capture.ps1", $hwnd
    Wait-For { Test-Path "$work\done" } 180 'the end of the session'
    $capture.WaitForExit(5000) | Out-Null
    Wait-For { -not [DemoWindow]::IsWindow($hwnd) } 15 'the window to close'
} finally {
    New-Item -ItemType File -Force "$work\done" | Out-Null
    Copy-Item $wtBackup $wtSettings -Force
}
uv run (Join-Path $PSScriptRoot 'frames-to-gif.py') $frames $OutFile $Width
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
