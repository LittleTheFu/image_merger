param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
Write-Host "Files count: $($Files.Count)"
Write-Host "Files: $Files"
Write-Host "args count: $($args.Count)"
