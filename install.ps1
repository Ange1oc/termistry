# One-command installer for terminal-setup.
#
#   irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex
#
# Downloads setup-terminal.ps1 to %TEMP% and runs it. Works from Windows PowerShell 5.1 and PowerShell 7.
# With parameters:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1))) -SshTabs myserver
# (kept ASCII-only on purpose: it is executed through Invoke-Expression)

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$SetupArgs = @())

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$url = 'https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/setup-terminal.ps1'
$file = Join-Path $env:TEMP 'setup-terminal.ps1'
Write-Host "  terminal-setup: downloading $url" -ForegroundColor DarkGray
Invoke-WebRequest $url -OutFile $file -UseBasicParsing

$shell = if ($PSVersionTable.PSVersion.Major -ge 7) { (Get-Process -Id $PID).Path } else { 'powershell.exe' }
& $shell -NoProfile -ExecutionPolicy Bypass -File $file @SetupArgs
