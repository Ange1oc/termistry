<#
.SYNOPSIS
  Renders text with ANSI codes as a terminal window PNG (Catppuccin colors, JetBrainsMono NF).
  Used by tools\make-screenshots.ps1 — the images in docs\ come from real command output.

.EXAMPLE
  .\render-terminal.ps1 -InputFile out.txt -OutFile docs\help.png -Title 'help' -Flavor mocha
#>
param(
    [Parameter(Mandatory)][string]$InputFile,
    [Parameter(Mandatory)][string]$OutFile,
    [string]$Title = '',
    [ValidateSet('mocha', 'macchiato', 'frappe', 'latte')][string]$Flavor = 'mocha',
    [int]$MinColumns = 72,
    [int]$MaxColumns = 110,
    [double]$FontSize = 13,
    [int]$Scale = 2,
    [string]$FontName = 'JetBrainsMono NF'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot '..\src\profile\palette.ps1')

$p = $CatppuccinFlavors[$Flavor]
$scheme = Get-TerminalScheme $Flavor
function C([int]$rgb) { [Drawing.Color]::FromArgb(255, ($rgb -shr 16) -band 255, ($rgb -shr 8) -band 255, $rgb -band 255) }
function Hex([string]$h) { [Drawing.ColorTranslator]::FromHtml($h) }
$ansi16 = @('black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white', 'brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite') | ForEach-Object { Hex $scheme[$_] }
$defaultFg = C $p.text
$defaultBg = C $p.base

function Color256([int]$n) {
    if ($n -lt 16) { return $ansi16[$n] }
    if ($n -lt 232) { $n -= 16; $levels = 0, 95, 135, 175, 215, 255; return [Drawing.Color]::FromArgb($levels[[int][math]::Floor($n / 36)], $levels[[int][math]::Floor($n / 6) % 6], $levels[$n % 6]) }
    $g = 8 + ($n - 232) * 10; [Drawing.Color]::FromArgb($g, $g, $g)
}

# ANSI text → lines of runs (Text, Fg, Bg, Bold, Italic, Dim, Underline)
$raw = [IO.File]::ReadAllText($InputFile)
$raw = $raw -replace "`e\][^`a`e]*(`a|`e\\)", '' -replace "`e[()][AB012]", '' -replace "`r", ''
$lines = [Collections.Generic.List[object]]::new()
$state = @{ Fg = $null; Bg = $null; Bold = $false; Italic = $false; Dim = $false; Underline = $false }
$current = [Collections.Generic.List[object]]::new()
$col = 0
function Flush-Run([string]$text) {
    if (-not $text) { return }
    $script:current.Add(@{ Text = $text; Fg = $state.Fg; Bg = $state.Bg; Bold = $state.Bold; Italic = $state.Italic; Dim = $state.Dim; Underline = $state.Underline })
}
$pos = 0
$rx = [regex]"`e\[([0-9;?]*)([A-Za-z])"
foreach ($m in $rx.Matches($raw)) {
    $chunk = $raw.Substring($pos, $m.Index - $pos)
    $pos = $m.Index + $m.Length
    $segments = $chunk -split "`n"
    for ($i = 0; $i -lt $segments.Count; $i++) {
        if ($i -gt 0) { $lines.Add($current); $current = [Collections.Generic.List[object]]::new(); $col = 0 }
        $seg = $segments[$i]
        if ($seg.Contains("`t")) { $sb = [Text.StringBuilder]::new(); $c = $col; foreach ($ch in $seg.ToCharArray()) { if ($ch -eq "`t") { $n = 8 - ($c % 8); [void]$sb.Append(' ' * $n); $c += $n } else { [void]$sb.Append($ch); $c++ } }; $seg = $sb.ToString() }
        Flush-Run $seg
        $col += $seg.Length
    }
    if ($m.Groups[2].Value -ne 'm') { continue }
    $params = if ($m.Groups[1].Value) { $m.Groups[1].Value -split ';' | ForEach-Object { [int]$_ } } else { @(0) }
    for ($k = 0; $k -lt $params.Count; $k++) {
        $n = $params[$k]
        switch ($n) {
            0  { $state.Fg = $null; $state.Bg = $null; $state.Bold = $false; $state.Italic = $false; $state.Dim = $false; $state.Underline = $false }
            1  { $state.Bold = $true }   2  { $state.Dim = $true }   3  { $state.Italic = $true }   4  { $state.Underline = $true }
            22 { $state.Bold = $false; $state.Dim = $false }   23 { $state.Italic = $false }   24 { $state.Underline = $false }
            39 { $state.Fg = $null }   49 { $state.Bg = $null }
            38 { if ($params[$k + 1] -eq 5) { $state.Fg = Color256 $params[$k + 2]; $k += 2 } elseif ($params[$k + 1] -eq 2) { $state.Fg = [Drawing.Color]::FromArgb($params[$k + 2], $params[$k + 3], $params[$k + 4]); $k += 4 } }
            48 { if ($params[$k + 1] -eq 5) { $state.Bg = Color256 $params[$k + 2]; $k += 2 } elseif ($params[$k + 1] -eq 2) { $state.Bg = [Drawing.Color]::FromArgb($params[$k + 2], $params[$k + 3], $params[$k + 4]); $k += 4 } }
            default {
                if ($n -ge 30 -and $n -le 37) { $state.Fg = $ansi16[$n - 30] }
                elseif ($n -ge 90 -and $n -le 97) { $state.Fg = $ansi16[$n - 90 + 8] }
                elseif ($n -ge 40 -and $n -le 47) { $state.Bg = $ansi16[$n - 40] }
                elseif ($n -ge 100 -and $n -le 107) { $state.Bg = $ansi16[$n - 100 + 8] }
            }
        }
    }
}
$tail = $raw.Substring($pos)
$segments = $tail -split "`n"
for ($i = 0; $i -lt $segments.Count; $i++) {
    if ($i -gt 0) { $lines.Add($current); $current = [Collections.Generic.List[object]]::new() }
    Flush-Run $segments[$i]
}
$lines.Add($current)
while ($lines.Count -and -not ($lines[$lines.Count - 1] | Where-Object { $_.Text.Trim() })) { $lines.RemoveAt($lines.Count - 1) }
while ($lines.Count -and -not ($lines[0] | Where-Object { $_.Text.Trim() })) { $lines.RemoveAt(0) }

# width in cells: a surrogate pair (icon) is one cell
function Cells([string]$s) { $n = 0; for ($i = 0; $i -lt $s.Length; $i++) { if (-not [char]::IsLowSurrogate($s[$i])) { $n++ } }; $n }
$maxLen = ($lines | ForEach-Object { ($_ | ForEach-Object { Cells $_.Text } | Measure-Object -Sum).Sum } | Measure-Object -Maximum).Maximum
$columns = [math]::Max($MinColumns, [math]::Min($MaxColumns, [int]$maxLen + 2))

$font = [Drawing.Font]::new($FontName, [single]($FontSize * $Scale), [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Point)
$fontBold = [Drawing.Font]::new($FontName, [single]($FontSize * $Scale), [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Point)
$fontItalic = [Drawing.Font]::new($FontName, [single]($FontSize * $Scale), [Drawing.FontStyle]::Italic, [Drawing.GraphicsUnit]::Point)
$fmt = [Drawing.StringFormat]::GenericTypographic.Clone()
$fmt.FormatFlags = $fmt.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces

$probe = [Drawing.Bitmap]::new(10, 10); $pg = [Drawing.Graphics]::FromImage($probe)
$cellW = [math]::Round($pg.MeasureString('M', $font, [Drawing.PointF]::Empty, $fmt).Width)
$cellH = [math]::Round($font.GetHeight($pg) * 1.25)
$pg.Dispose(); $probe.Dispose()

$pad = 22 * $Scale; $titleH = 40 * $Scale; $margin = 18 * $Scale; $radius = 12 * $Scale
[int]$cellW = $cellW; [int]$cellH = $cellH
[int]$w = $columns * $cellW + 2 * $pad
[int]$h = $lines.Count * $cellH + 2 * $pad + $titleH
$bmp = [Drawing.Bitmap]::new($w + 2 * $margin, $h + 2 * $margin)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([Drawing.Color]::Transparent)

for ($i = 6; $i -ge 1; $i--) {
    $sh = [Drawing.Drawing2D.GraphicsPath]::new(); $r = $radius + $i * $Scale
    $x = $margin - $i * $Scale; $y = $margin - $i * $Scale + 3 * $Scale; $ww = $w + 2 * $i * $Scale; $hh = $h + 2 * $i * $Scale
    $sh.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90); $sh.AddArc($x + $ww - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90); $sh.AddArc($x + $ww - 2 * $r, $y + $hh - 2 * $r, 2 * $r, 2 * $r, 0, 90); $sh.AddArc($x, $y + $hh - 2 * $r, 2 * $r, 2 * $r, 90, 90); $sh.CloseFigure()
    $g.FillPath([Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(10, 0, 0, 0)), $sh)
}
$win = [Drawing.Drawing2D.GraphicsPath]::new()
$win.AddArc($margin, $margin, 2 * $radius, 2 * $radius, 180, 90); $win.AddArc($margin + $w - 2 * $radius, $margin, 2 * $radius, 2 * $radius, 270, 90)
$win.AddArc($margin + $w - 2 * $radius, $margin + $h - 2 * $radius, 2 * $radius, 2 * $radius, 0, 90); $win.AddArc($margin, $margin + $h - 2 * $radius, 2 * $radius, 2 * $radius, 90, 90); $win.CloseFigure()
$g.FillPath([Drawing.SolidBrush]::new($defaultBg), $win)
$g.SetClip($win)
$g.FillRectangle([Drawing.SolidBrush]::new((C $p.mantle)), $margin, $margin, $w, $titleH)
$dots = @((C $p.red), (C $p.yellow), (C $p.green))
for ($i = 0; $i -lt 3; $i++) { $g.FillEllipse([Drawing.SolidBrush]::new($dots[$i]), $margin + $pad + $i * 20 * $Scale, $margin + $titleH / 2 - 6 * $Scale, 12 * $Scale, 12 * $Scale) }
if ($Title) {
    $tf = [Drawing.Font]::new($FontName, [single](($FontSize - 2) * $Scale), [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Point)
    $tsz = $g.MeasureString($Title, $tf, [Drawing.PointF]::Empty, $fmt)
    $g.DrawString($Title, $tf, [Drawing.SolidBrush]::new((C $p.overlay1)), $margin + ($w - $tsz.Width) / 2, $margin + ($titleH - $tsz.Height) / 2, $fmt)
}

$y = $margin + $titleH + $pad
foreach ($line in $lines) {
    $x = $margin + $pad; $colIndex = 0
    foreach ($run in $line) {
        $fg = if ($run.Fg) { $run.Fg } else { $defaultFg }
        if ($run.Dim) { $fg = [Drawing.Color]::FromArgb(255, [int](($fg.R + $defaultBg.R) / 2), [int](($fg.G + $defaultBg.G) / 2), [int](($fg.B + $defaultBg.B) / 2)) }
        $f = if ($run.Bold) { $fontBold } elseif ($run.Italic) { $fontItalic } else { $font }
        $brush = [Drawing.SolidBrush]::new($fg)
        $text = $run.Text
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($colIndex -ge $columns) { break }
            $ch = $text[$i]
            $glyph = if ([char]::IsHighSurrogate($ch) -and $i + 1 -lt $text.Length) { $text.Substring($i, 2) } else { [string]$ch }
            if ($glyph.Length -eq 2) { $i++ }
            if ($run.Bg) { $g.FillRectangle([Drawing.SolidBrush]::new($run.Bg), $x, $y, $cellW, $cellH) }
            if ($glyph -ne ' ') { $g.DrawString($glyph, $f, $brush, [single]$x, [single]($y + ($cellH - $font.GetHeight($g)) / 2), $fmt) }
            if ($run.Underline) { $g.FillRectangle($brush, $x, $y + $cellH - 2 * $Scale, $cellW, [int]$Scale) }
            $x += $cellW; $colIndex++
        }
    }
    $y += $cellH
}
$g.ResetClip()
New-Item -ItemType Directory -Force (Split-Path $OutFile) | Out-Null
$bmp.Save($OutFile, [Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"  ✓ $OutFile  ($columns×$($lines.Count))"
