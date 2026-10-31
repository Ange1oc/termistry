# Every theme uses the same 26 Catppuccin-style slots, so one table drives Windows Terminal,
# the oh-my-posh prompt, PSReadLine colors and fzf. Add a theme here and it works everywhere.
$Themes = [ordered]@{
    mocha = @{
        title = 'Catppuccin Mocha'; dark = $true
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xCDD6F4; subtext1 = 0xBAC2DE; subtext0 = 0xA6ADC8
        overlay2 = 0x9399B2; overlay1 = 0x7F849C; overlay0 = 0x6C7086; surface2 = 0x585B70; surface1 = 0x45475A
        surface0 = 0x313244; base = 0x1E1E2E; mantle = 0x181825; crust = 0x11111B
    }
    macchiato = @{
        title = 'Catppuccin Macchiato'; dark = $true
        rosewater = 0xF4DBD6; flamingo = 0xF0C6C6; pink = 0xF5BDE6; mauve = 0xC6A0F6; red = 0xED8796; maroon = 0xEE99A0
        peach = 0xF5A97F; yellow = 0xEED49F; green = 0xA6DA95; teal = 0x8BD5CA; sky = 0x91D7E3; sapphire = 0x7DC4E4
        blue = 0x8AADF4; lavender = 0xB7BDF8; text = 0xCAD3F5; subtext1 = 0xB8C0E0; subtext0 = 0xA5ADCB
        overlay2 = 0x939AB7; overlay1 = 0x8087A2; overlay0 = 0x6E738D; surface2 = 0x5B6078; surface1 = 0x494D64
        surface0 = 0x363A4F; base = 0x24273A; mantle = 0x1E2030; crust = 0x181926
    }
    frappe = @{
        title = 'Catppuccin Frappe'; dark = $true
        rosewater = 0xF2D5CF; flamingo = 0xEEBEBE; pink = 0xF4B8E4; mauve = 0xCA9EE6; red = 0xE78284; maroon = 0xEA999C
        peach = 0xEF9F76; yellow = 0xE5C890; green = 0xA6D189; teal = 0x81C8BE; sky = 0x99D1DB; sapphire = 0x85C1DC
        blue = 0x8CAAEE; lavender = 0xBABBF1; text = 0xC6D0F5; subtext1 = 0xB5BFE2; subtext0 = 0xA5ADCE
        overlay2 = 0x949CBB; overlay1 = 0x838BA7; overlay0 = 0x737994; surface2 = 0x626880; surface1 = 0x51576D
        surface0 = 0x414559; base = 0x303446; mantle = 0x292C3C; crust = 0x232634
    }
    latte = @{
        title = 'Catppuccin Latte'; dark = $false
        rosewater = 0xDC8A78; flamingo = 0xDD7878; pink = 0xEA76CB; mauve = 0x8839EF; red = 0xD20F39; maroon = 0xE64553
        peach = 0xFE640B; yellow = 0xDF8E1D; green = 0x40A02B; teal = 0x179299; sky = 0x04A5E5; sapphire = 0x209FB5
        blue = 0x1E66F5; lavender = 0x7287FD; text = 0x4C4F69; subtext1 = 0x5C5F77; subtext0 = 0x6C6F85
        overlay2 = 0x7C7F93; overlay1 = 0x8C8FA1; overlay0 = 0x9CA0B0; surface2 = 0xACB0BE; surface1 = 0xBCC0CC
        surface0 = 0xCCD0DA; base = 0xEFF1F5; mantle = 0xE6E9EF; crust = 0xDCE0E8
    }
    black = @{
        title = 'Black'; dark = $true
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xE4E4E4; subtext1 = 0xC8C8C8; subtext0 = 0xAAAAAA
        overlay2 = 0x8A8A8A; overlay1 = 0x707070; overlay0 = 0x585858; surface2 = 0x3C3C3C; surface1 = 0x2A2A2A
        surface0 = 0x1A1A1A; base = 0x000000; mantle = 0x000000; crust = 0x000000
    }
    gruvbox = @{
        title = 'Gruvbox Dark'; dark = $true
        rosewater = 0xEBDBB2; flamingo = 0xFE8019; pink = 0xD3869B; mauve = 0xD3869B; red = 0xFB4934; maroon = 0xCC241D
        peach = 0xFE8019; yellow = 0xFABD2F; green = 0xB8BB26; teal = 0x8EC07C; sky = 0x7DAEA3; sapphire = 0x458588
        blue = 0x83A598; lavender = 0xD3869B; text = 0xEBDBB2; subtext1 = 0xD5C4A1; subtext0 = 0xBDAE93
        overlay2 = 0xA89984; overlay1 = 0x928374; overlay0 = 0x7C6F64; surface2 = 0x665C54; surface1 = 0x504945
        surface0 = 0x3C3836; base = 0x282828; mantle = 0x1D2021; crust = 0x161616
    }
    dracula = @{
        title = 'Dracula'; dark = $true
        rosewater = 0xF8F8F2; flamingo = 0xFF79C6; pink = 0xFF79C6; mauve = 0xBD93F9; red = 0xFF5555; maroon = 0xFF6E6E
        peach = 0xFFB86C; yellow = 0xF1FA8C; green = 0x50FA7B; teal = 0x8BE9FD; sky = 0x8BE9FD; sapphire = 0x80BFFF
        blue = 0x8BE9FD; lavender = 0xBD93F9; text = 0xF8F8F2; subtext1 = 0xE6E6E0; subtext0 = 0xC9C9C4
        overlay2 = 0x959DC9; overlay1 = 0x7B86B8; overlay0 = 0x6272A4; surface2 = 0x565A75; surface1 = 0x44475A
        surface0 = 0x343746; base = 0x282A36; mantle = 0x21222C; crust = 0x191A21
    }
    tokyonight = @{
        title = 'Tokyo Night'; dark = $true
        rosewater = 0xC0CAF5; flamingo = 0xFF9E64; pink = 0xBB9AF7; mauve = 0xBB9AF7; red = 0xF7768E; maroon = 0xDB4B4B
        peach = 0xFF9E64; yellow = 0xE0AF68; green = 0x9ECE6A; teal = 0x1ABC9C; sky = 0x7DCFFF; sapphire = 0x2AC3DE
        blue = 0x7AA2F7; lavender = 0xBB9AF7; text = 0xC0CAF5; subtext1 = 0xA9B1D6; subtext0 = 0x9AA5CE
        overlay2 = 0x8A93B8; overlay1 = 0x737AA2; overlay0 = 0x565F89; surface2 = 0x414868; surface1 = 0x3B4261
        surface0 = 0x292E42; base = 0x1A1B26; mantle = 0x16161E; crust = 0x0F0F14
    }
    nord = @{
        title = 'Nord'; dark = $true
        rosewater = 0xECEFF4; flamingo = 0xD08770; pink = 0xB48EAD; mauve = 0xB48EAD; red = 0xBF616A; maroon = 0xBF616A
        peach = 0xD08770; yellow = 0xEBCB8B; green = 0xA3BE8C; teal = 0x8FBCBB; sky = 0x88C0D0; sapphire = 0x5E81AC
        blue = 0x81A1C1; lavender = 0xB48EAD; text = 0xECEFF4; subtext1 = 0xE5E9F0; subtext0 = 0xD8DEE9
        overlay2 = 0x93A0B5; overlay1 = 0x7B88A1; overlay0 = 0x616E88; surface2 = 0x4C566A; surface1 = 0x434C5E
        surface0 = 0x3B4252; base = 0x2E3440; mantle = 0x272C36; crust = 0x20242C
    }
    rosepine = @{
        title = 'Rose Pine'; dark = $true
        rosewater = 0xEBBCBA; flamingo = 0xEBBCBA; pink = 0xEBBCBA; mauve = 0xC4A7E7; red = 0xEB6F92; maroon = 0xEB6F92
        peach = 0xF6C177; yellow = 0xF6C177; green = 0x9CCFD8; teal = 0x31748F; sky = 0x9CCFD8; sapphire = 0x31748F
        blue = 0x9CCFD8; lavender = 0xC4A7E7; text = 0xE0DEF4; subtext1 = 0xD0CDE6; subtext0 = 0xB8B5CC
        overlay2 = 0xA8A4C0; overlay1 = 0x908CAA; overlay0 = 0x6E6A86; surface2 = 0x524F67; surface1 = 0x403D52
        surface0 = 0x26233A; base = 0x191724; mantle = 0x1F1D2E; crust = 0x141220
    }
}

$ThemeFile = Join-Path $HOME '.config\termistry\theme'

function Get-ThemeName {
    $name = if (Test-Path $ThemeFile) { (Get-Content $ThemeFile -First 1).Trim().ToLower() }
    if ($name -and $Themes.Contains($name)) { $name } else { 'mocha' }
}

function ConvertTo-Hex([int]$Rgb) { '#{0:X6}' -f $Rgb }

function Get-TerminalScheme([string]$Name) {
    $p = $Themes[$Name]
    [ordered]@{
        name = $p.title
        background = ConvertTo-Hex $p.base; foreground = ConvertTo-Hex $p.text
        cursorColor = ConvertTo-Hex $p.rosewater; selectionBackground = ConvertTo-Hex $p.surface2
        black = ConvertTo-Hex $p.surface1; red = ConvertTo-Hex $p.red; green = ConvertTo-Hex $p.green; yellow = ConvertTo-Hex $p.yellow
        blue = ConvertTo-Hex $p.blue; purple = ConvertTo-Hex $p.mauve; cyan = ConvertTo-Hex $p.teal; white = ConvertTo-Hex $p.subtext1
        brightBlack = ConvertTo-Hex $p.surface2; brightRed = ConvertTo-Hex $p.red; brightGreen = ConvertTo-Hex $p.green; brightYellow = ConvertTo-Hex $p.yellow
        brightBlue = ConvertTo-Hex $p.blue; brightPurple = ConvertTo-Hex $p.mauve; brightCyan = ConvertTo-Hex $p.teal; brightWhite = ConvertTo-Hex $p.subtext0
    }
}

function Get-TerminalTheme([string]$Name) {
    $p = $Themes[$Name]
    [ordered]@{
        name = $p.title
        tab = [ordered]@{ background = (ConvertTo-Hex $p.base) + 'FF'; unfocusedBackground = $null; showCloseButton = 'hover' }
        tabRow = [ordered]@{ background = (ConvertTo-Hex $p.mantle) + 'FF'; unfocusedBackground = (ConvertTo-Hex $p.crust) + 'FF' }
        window = [ordered]@{ applicationTheme = $(if ($p.dark) { 'dark' } else { 'light' }); useMica = $false }
    }
}

