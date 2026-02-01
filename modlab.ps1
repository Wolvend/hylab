param(
  [Parameter(Position=0)]
  [ValidateSet('help','scan','boot','join','report','bisect')]
  [string]$Command = 'help'
)

switch ($Command) {
  'help' {
    Write-Host "Hytale Mod Lab" 
    Write-Host "Commands: scan | boot | join | report | bisect" 
    Write-Host "(scaffold only; implementation coming next)" 
  }
  default {
    Write-Host "Not implemented yet: $Command" 
    exit 1
  }
}
