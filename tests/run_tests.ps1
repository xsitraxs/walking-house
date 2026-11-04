# run_tests.ps1 — Helper script to run headless tests in Windows PowerShell
$ErrorActionPreference = "Stop"
$godotBin = "E:\godot\Godot_v4.7.2-stable_win64.exe"
$projectDir = "E:\project"

Write-Host "Invoking Godot 4 Headless E2E Test Runner..."
$output = & $godotBin --headless --path $projectDir -s res://tests/test_runner.gd | Out-String
Write-Host $output

$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "All tests passed (or pending milestone implementation)." -ForegroundColor Green
} else {
    Write-Host "Test run failed with exit code $exitCode." -ForegroundColor Red
}

exit $exitCode
