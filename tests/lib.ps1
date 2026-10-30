# Shared by run.ps1 and profile.tests.ps1: a Test/Assert pair and nothing else, so no module is needed.
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TcOk = "$([char]27)[32m"; $script:TcBad = "$([char]27)[31m"; $script:TcDim = "$([char]27)[90m"; $script:TcR = "$([char]27)[0m"

function Section([string]$Title) { Write-Host "`n$TcDim── $Title$TcR" }

function Test([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:TestsPassed++; Write-Host "  $TcOk✓$TcR $Name" }
    catch {
        $script:TestsFailed++
        $why = ($_.Exception.Message -replace '\s+', ' ').Trim()
        Write-Host "  $TcBad✗ $Name$TcR  $TcDim$why$TcR"
    }
}
function Skip([string]$Name, [string]$Why) { Write-Host "  $TcDim- $Name  ($Why)$TcR" }

function Clip([string]$Text, [int]$Max = 160) { $t = $Text -replace '\s+', ' '; if ($t.Length -gt $Max) { $t.Substring(0, $Max) + '…' } else { $t } }
function Assert($Condition, [string]$Because) { if (-not $Condition) { throw $Because } }
function AssertEq($Actual, $Expected, [string]$What) { if ("$Actual" -ne "$Expected") { throw "$What`: expected '$Expected', got '$(Clip "$Actual")'" } }
function AssertMatch([string]$Text, [string]$Pattern, [string]$What) { if ($Text -notmatch $Pattern) { throw "$What`: '$Pattern' not found in: $(Clip $Text)" } }
function AssertNotMatch([string]$Text, [string]$Pattern, [string]$What) { if ($Text -match $Pattern) { throw "$What`: '$Pattern' should not be in: $(Clip $Text)" } }

function Plain([string]$Text) { $Text -replace "`e\[[0-9;]*m", '' -replace "`e\][^`a]*`a", '' }
# Everything a command prints, Write-Host included, as one string; error records are kept apart
function Run([scriptblock]$Block) {
    $items = @(& $Block *>&1)
    @{ Text = ($items | ForEach-Object { "$_" }) -join "`n"; Errors = @($items | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) }
}
function Capture([scriptblock]$Block) { (Run $Block).Text }

function Write-TestSummary([switch]$Machine) {
    $color = if ($script:TestsFailed) { $TcBad } else { $TcOk }
    Write-Host "`n  $color$($script:TestsPassed) passed, $($script:TestsFailed) failed$TcR"
    if ($Machine) { Write-Host "##result passed=$($script:TestsPassed) failed=$($script:TestsFailed)" }
    $script:TestsFailed
}
