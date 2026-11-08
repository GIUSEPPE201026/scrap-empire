$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $project 'test_logs'
$stdoutPath = Join-Path $logDirectory 'normal_launch_stdout.log'
$stderrPath = Join-Path $logDirectory 'normal_launch_stderr.log'
$enginePath = Join-Path $project 'tools\Godot_v4.3-stable_win64.exe'
$launcher = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', 'AVVIA_GIOCO.bat') -WorkingDirectory $project -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
$game = @()
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$menuReady = $false
try {
    while($timer.Elapsed.TotalSeconds -lt 60) {
        if($game.Count -eq 0) {
            $game = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($launcher.Id)" | Where-Object { $_.ExecutablePath -eq $enginePath })
        }
        $out = if(Test-Path -LiteralPath $stdoutPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutPath } else { '' }
        $err = if(Test-Path -LiteralPath $stderrPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $stderrPath } else { '' }
        if(($out + $err) -match 'SCRIPT ERROR|USER ERROR|ERROR:') { throw 'Normal launch reported an engine/script error; inspect logs.' }
        if($game.Count -gt 0 -and $out -match '\[MAIN_MENU\] Main menu scene loaded') { $menuReady=$true; break }
        $launcher.Refresh()
        if($launcher.HasExited) { throw 'Normal launcher exited before the menu was ready.' }
        Start-Sleep -Milliseconds 250
    }
    if(!$menuReady) { throw 'Normal launch did not reach the menu within 60 seconds; inspect logs.' }
    Start-Sleep -Milliseconds 500
    $out = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutPath
    $err = Get-Content -Raw -Encoding UTF8 -LiteralPath $stderrPath
    if(($out + $err) -match 'SCRIPT ERROR|USER ERROR|ERROR:') { throw 'Normal menu reported an engine/script error; inspect logs.' }
    $game | Select-Object ProcessId, ExecutablePath, CommandLine | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $logDirectory 'normal_launch_process.json')
    Write-Output ('NORMAL_LAUNCH_RESULT: bundled engine reached clean main menu in '+[math]::Round($timer.Elapsed.TotalSeconds,2)+' seconds.')
} finally {
    foreach($process in $game) {
        $running = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.ProcessId)"
        if($running -and $running.ParentProcessId -eq $launcher.Id -and $running.ExecutablePath -eq $enginePath) {
            Stop-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
        }
    }
    $launcher.Refresh()
    if(!$launcher.HasExited) { Stop-Process -Id $launcher.Id -ErrorAction SilentlyContinue }
}
