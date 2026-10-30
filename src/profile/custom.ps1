# custom.ps1 — yours. setup-terminal.ps1 never overwrites this file. Loaded after toolkit.ps1; check with: reload
#
#   $TerminalSetup.Abbreviations = $false     # g␣ → git␣
#   $TerminalSetup.LayoutFix     = $false     # Russian layout fix on Enter
#   $TerminalSetup.Predictions   = 20         # history suggestions (0 — PSReadLine default 10)
#
#   abbr gcm 'git commit -m "%"'              # % — cursor position
#   abbr -Remove d
#
#   function deploy { ssh prod 'cd app && git pull && docker compose up -d' }   # shows up in help
#
#   Commands in other languages: files in bin\ next to this file (new name.py); "# help: ..." is the caption.
#   $ScriptRunners['.ts'] = @('bun', 'node')  # which runner to use per extension
