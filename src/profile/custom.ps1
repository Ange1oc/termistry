# custom.ps1 - yours. setup-terminal.ps1 never overwrites this file. Loaded after toolkit.ps1; check with: reload
#
#   $Termistry.Abbreviations = $false     # g␣ → git␣
#   $Termistry.LayoutFix     = $false     # Russian layout fix on Enter
#   $Termistry.Predictions   = 20         # history suggestions (0 - PSReadLine default 10)
#   $Termistry.Kube          = 'always'   # kubernetes context in the prompt: auto (k8s folders and prod only), always, off
#   $Termistry.Workspace     = $false     # no Workspace marks in the prompt (work still works)
#
#   abbr gcm 'git commit -m "%"'              # % - cursor position
#   abbr -Remove d
#
#   function deploy { ssh prod 'cd app && git pull && docker compose up -d' }   # shows up in help
#
#   Commands in other languages: files in bin\ next to this file (new name.py); "# help: ..." is the caption.
#   $ScriptRunners['.ts'] = @('bun', 'node')  # which runner to use per extension
