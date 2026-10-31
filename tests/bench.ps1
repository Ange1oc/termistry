<#
  Measures what the prompt and the project list cost, in a sandbox like run.ps1 does. Not a pass/fail test:
  it prints numbers so a change can be compared with the version before it.
    .\tests\bench.ps1                       the profile in src\
    .\tests\bench.ps1 -Profile <folder>     another copy, for example an older checkout
#>
param([string]$Profile = (Join-Path (Split-Path $PSScriptRoot) 'src\profile'), [int[]]$Projects = @(100, 1000, 10000))
$ErrorActionPreference = 'Stop'
$work = Join-Path ([IO.Path]::GetTempPath()) "termistry-bench-$PID"
New-Item -ItemType Directory -Force "$work\home\.config\termistry", "$work\profile" | Out-Null
Copy-Item "$Profile\*" "$work\profile" -Recurse
Set-Content "$work\home\.config\termistry\lang" 'en'

# a repo with markers, and 200 plain folders for "a new folder every prompt"
$repo = "$work\shop"
New-Item -ItemType Directory -Force "$repo\src\deep\er" | Out-Null
'{}' | Set-Content "$repo\package.json"; '' | Set-Content "$repo\compose.yaml"
& git -C $repo init -q 2>&1 | Out-Null
1..200 | ForEach-Object { New-Item -ItemType Directory -Force "$work\dirs\d$_" | Out-Null }

$code = @"
`$ErrorActionPreference = 'Stop'
. '$work\profile\Microsoft.PowerShell_profile.ps1' *> `$null
`$global:TsGit.Time = [datetime]::Now
function Measure-Ms([int]`$Times, [scriptblock]`$Block) {
    & `$Block | Out-Null
    `$sw = [Diagnostics.Stopwatch]::StartNew()
    for (`$i = 0; `$i -lt `$Times; `$i++) { & `$Block | Out-Null }
    [math]::Round(`$sw.Elapsed.TotalMilliseconds / `$Times, 3)
}
"prompt, same folder (repo root)    {0,8} ms" -f (Measure-Ms 500 { Get-TsPrompt -Dir '$repo' -Width 120 })
"prompt, same folder (deep inside)  {0,8} ms" -f (Measure-Ms 500 { Get-TsPrompt -Dir '$repo\src\deep\er' -Width 120 })
`$dirs = 1..200 | ForEach-Object { "$work\dirs\d`$_" }; `$n = 0
"prompt, a folder seen first time   {0,8} ms" -f (Measure-Ms 200 { `$n++; `$global:TsGitRoots.Clear(); if (`$global:TsCtx) { `$global:TsCtx.Clear() }; Get-TsPrompt -Dir `$dirs[`$n % 200] -Width 120 })
Set-Location '$repo'
"prompt function, same folder       {0,8} ms" -f (Measure-Ms 500 { prompt })
if (Get-Command Read-TsProjects -ErrorAction Ignore) {
    foreach (`$count in $($Projects -join ',')) {
        `$lines = [Collections.Generic.List[string]]::new()
        for (`$i = 0; `$i -lt `$count; `$i++) { `$lines.Add("C:\code\group`$(`$i % 50)\project-`$i``t`$(if (`$i % 20 -eq 0) { 'pin' })``tnode") }
        [IO.File]::WriteAllLines(`$global:TsProjectsFile, `$lines)
        "projects: {0,5}  read the list     {1,8} ms" -f `$count, (Measure-Ms 5 { `$global:TsProjects.Map = `$null; Read-TsProjects })
        "projects: {0,5}  prompt lookup     {1,8} ms" -f `$count, (Measure-Ms 500 { Get-TsPrompt -Dir '$repo\src' -Width 120 })
        "projects: {0,5}  picker lines      {1,8} ms" -f `$count, (Measure-Ms 3 { Get-TsWorkLines })
    }
}
"@
pwsh -NoProfile -NoLogo -Command "`$env:USERPROFILE = '$work\home'; `$env:HOME = '$work\home'; pwsh -NoProfile -NoLogo -Command `$args[0]" $code

$starts = foreach ($i in 1..5) {
    [int](pwsh -NoProfile -NoLogo -Command "`$env:USERPROFILE = '$work\home'; `$env:HOME = '$work\home'; pwsh -NoProfile -NoLogo -Command '`$sw = [Diagnostics.Stopwatch]::StartNew(); . ''$work\profile\Microsoft.PowerShell_profile.ps1'' *> `$null; `$sw.ElapsedMilliseconds'")
}
"profile load (median of 5)         {0,8} ms" -f ($starts | Sort-Object)[2]
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
