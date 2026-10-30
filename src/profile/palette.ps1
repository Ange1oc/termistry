$CatppuccinFlavors = [ordered]@{
    mocha = @{
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xCDD6F4; subtext1 = 0xBAC2DE; subtext0 = 0xA6ADC8
        overlay2 = 0x9399B2; overlay1 = 0x7F849C; overlay0 = 0x6C7086; surface2 = 0x585B70; surface1 = 0x45475A
        surface0 = 0x313244; base = 0x1E1E2E; mantle = 0x181825; crust = 0x11111B; dark = $true
    }
    macchiato = @{
        rosewater = 0xF4DBD6; flamingo = 0xF0C6C6; pink = 0xF5BDE6; mauve = 0xC6A0F6; red = 0xED8796; maroon = 0xEE99A0
        peach = 0xF5A97F; yellow = 0xEED49F; green = 0xA6DA95; teal = 0x8BD5CA; sky = 0x91D7E3; sapphire = 0x7DC4E4
        blue = 0x8AADF4; lavender = 0xB7BDF8; text = 0xCAD3F5; subtext1 = 0xB8C0E0; subtext0 = 0xA5ADCB
        overlay2 = 0x939AB7; overlay1 = 0x8087A2; overlay0 = 0x6E738D; surface2 = 0x5B6078; surface1 = 0x494D64
        surface0 = 0x363A4F; base = 0x24273A; mantle = 0x1E2030; crust = 0x181926; dark = $true
    }
    frappe = @{
        rosewater = 0xF2D5CF; flamingo = 0xEEBEBE; pink = 0xF4B8E4; mauve = 0xCA9EE6; red = 0xE78284; maroon = 0xEA999C
        peach = 0xEF9F76; yellow = 0xE5C890; green = 0xA6D189; teal = 0x81C8BE; sky = 0x99D1DB; sapphire = 0x85C1DC
        blue = 0x8CAAEE; lavender = 0xBABBF1; text = 0xC6D0F5; subtext1 = 0xB5BFE2; subtext0 = 0xA5ADCE
        overlay2 = 0x949CBB; overlay1 = 0x838BA7; overlay0 = 0x737994; surface2 = 0x626880; surface1 = 0x51576D
        surface0 = 0x414559; base = 0x303446; mantle = 0x292C3C; crust = 0x232634; dark = $true
    }
    latte = @{
        rosewater = 0xDC8A78; flamingo = 0xDD7878; pink = 0xEA76CB; mauve = 0x8839EF; red = 0xD20F39; maroon = 0xE64553
        peach = 0xFE640B; yellow = 0xDF8E1D; green = 0x40A02B; teal = 0x179299; sky = 0x04A5E5; sapphire = 0x209FB5
        blue = 0x1E66F5; lavender = 0x7287FD; text = 0x4C4F69; subtext1 = 0x5C5F77; subtext0 = 0x6C6F85
        overlay2 = 0x7C7F93; overlay1 = 0x8C8FA1; overlay0 = 0x9CA0B0; surface2 = 0xACB0BE; surface1 = 0xBCC0CC
        surface0 = 0xCCD0DA; base = 0xEFF1F5; mantle = 0xE6E9EF; crust = 0xDCE0E8; dark = $false
    }
}

$ThemeFile = Join-Path $HOME '.config\terminal-setup\theme'

function Get-ThemeName {
    $name = if (Test-Path $ThemeFile) { (Get-Content $ThemeFile -First 1).Trim().ToLower() }
    if ($name -and $CatppuccinFlavors.Contains($name)) { $name } else { 'mocha' }
}

function ConvertTo-Hex([int]$Rgb) { '#{0:X6}' -f $Rgb }

function Get-TerminalScheme([string]$Flavor) {
    $p = $CatppuccinFlavors[$Flavor]
    [ordered]@{
        name = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Flavor))"
        background = ConvertTo-Hex $p.base; foreground = ConvertTo-Hex $p.text
        cursorColor = ConvertTo-Hex $p.rosewater; selectionBackground = ConvertTo-Hex $p.surface2
        black = ConvertTo-Hex $p.surface1; red = ConvertTo-Hex $p.red; green = ConvertTo-Hex $p.green; yellow = ConvertTo-Hex $p.yellow
        blue = ConvertTo-Hex $p.blue; purple = ConvertTo-Hex $p.mauve; cyan = ConvertTo-Hex $p.teal; white = ConvertTo-Hex $p.subtext1
        brightBlack = ConvertTo-Hex $p.surface2; brightRed = ConvertTo-Hex $p.red; brightGreen = ConvertTo-Hex $p.green; brightYellow = ConvertTo-Hex $p.yellow
        brightBlue = ConvertTo-Hex $p.blue; brightPurple = ConvertTo-Hex $p.mauve; brightCyan = ConvertTo-Hex $p.teal; brightWhite = ConvertTo-Hex $p.subtext0
    }
}

function Get-TerminalTheme([string]$Flavor) {
    $p = $CatppuccinFlavors[$Flavor]
    [ordered]@{
        name = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Flavor))"
        tab = [ordered]@{ background = (ConvertTo-Hex $p.base) + 'FF'; unfocusedBackground = $null; showCloseButton = 'hover' }
        tabRow = [ordered]@{ background = (ConvertTo-Hex $p.mantle) + 'FF'; unfocusedBackground = (ConvertTo-Hex $p.crust) + 'FF' }
        window = [ordered]@{ applicationTheme = $(if ($p.dark) { 'dark' } else { 'light' }); useMica = $false }
    }
}
