$checks = @(
  @{Name='format_initial'; Exe='D:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe'; Arguments=@('format','--output=none','--set-exit-if-changed','.')},
  @{Name='analyze_initial'; Exe='D:\flutter\flutter\bin\flutter.bat'; Arguments=@('analyze')},
  @{Name='test_initial'; Exe='D:\flutter\flutter\bin\flutter.bat'; Arguments=@('test')},
  @{Name='outdated'; Exe='D:\flutter\flutter\bin\flutter.bat'; Arguments=@('pub','outdated')},
  @{Name='apk_initial'; Exe='D:\flutter\flutter\bin\flutter.bat'; Arguments=@('build','apk','--release')}
)
$results = @()
foreach ($check in $checks) {
  $started = [DateTime]::UtcNow
  & $check.Exe @($check.Arguments) *> "audit_logs/$($check.Name).log"
  $checkExit = $LASTEXITCODE
  $results += [PSCustomObject]@{name=$check.Name; exitCode=$checkExit; seconds=([DateTime]::UtcNow-$started).TotalSeconds}
  $results | ConvertTo-Json | Set-Content -Encoding UTF8 audit_logs/initial_results.json
  Write-Output "$($check.Name): exit $checkExit"
  Get-Content "audit_logs/$($check.Name).log" -Tail 8
}
