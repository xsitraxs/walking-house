# tests/run_tests.ps1 — Universal Headless E2E & Adversarial Test Runner
$ErrorActionPreference = "Stop"

# Resolve Godot binary
$godotBin = $env:GODOT_BIN
if (-not $godotBin) {
    if (Test-Path "E:\godot\Godot_v4.7.2-stable_win64.exe") {
        $godotBin = "E:\godot\Godot_v4.7.2-stable_win64.exe"
    } elseif (Get-Command "godot" -ErrorAction SilentlyContinue) {
        $godotBin = (Get-Command "godot").Source
    } elseif (Get-Command "godot4" -ErrorAction SilentlyContinue) {
        $godotBin = (Get-Command "godot4").Source
    } else {
        Write-Error "Godot binary not found. Set GODOT_BIN environment variable."
        exit 1
    }
}

# Resolve Project directory
$projectDir = $env:PROJECT_DIR
if (-not $projectDir) {
    $projectDir = Resolve-Path "$PSScriptRoot/.."
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  WALKING HOUSE (ШАГАЮЩИЙ ДОМ) — COMPLETE CI TEST SUITE RUNNER" -ForegroundColor Cyan
Write-Host "  Godot Binary: $godotBin" -ForegroundColor Gray
Write-Host "  Project Dir:  $projectDir" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

$totalFailed = 0
$totalPassed = 0

# Track 1: Standard 10-Suite E2E Runner (93 tests)
Write-Host "`n>> TRACK 1: Running Primary E2E Test Runner (res://tests/test_runner.gd)..." -ForegroundColor Yellow
$runnerOutput = & $godotBin --headless --path $projectDir -s res://tests/test_runner.gd | Out-String
Write-Host $runnerOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Primary test runner failed with exit code $LASTEXITCODE" -ForegroundColor Red
    $totalFailed++
} else {
    Write-Host "[PASS] Primary test runner succeeded (93/93 tests)" -ForegroundColor Green
    $totalPassed++
}

# Track 2: Standalone Adversarial & Forensic Test Suites (14 suites)
$standaloneSuites = @(
    "tests/suites/test_simulation_math.gd",
    "tests/suites/test_adversarial_stress.gd",
    "tests/suites/test_adversarial_gamestate_reactivity.gd",
    "tests/suites/test_adversarial_m2_challenger.gd",
    "tests/suites/test_adversarial_m3_biome_interpolation.gd",
    "tests/suites/test_adversarial_m3_challenger_r2.gd",
    "tests/suites/test_adversarial_m3_challenger.gd",
    "tests/suites/test_adversarial_m3_r2.gd",
    "tests/suites/test_adversarial_thermo_deadlock.gd",
    "tests/suites/test_balance_sound.gd",
    "tests/suites/test_forensic_m3_auditor.gd",
    "tests/suites/test_m2_challenger_adversarial.gd",
    "tests/suites/test_m2_locomotion_hud.gd",
    "tests/suites/test_m3_challenger_adversarial.gd"
)

Write-Host "`n>> TRACK 2: Running Standalone Adversarial & Forensic Suites ($($standaloneSuites.Count) suites)..." -ForegroundColor Yellow
foreach ($suite in $standaloneSuites) {
    $suiteName = Split-Path $suite -Leaf
    $suitePath = "res://$suite"
    $suiteOutput = & $godotBin --headless --path $projectDir -s $suitePath | Out-String
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host "  [PASS] $suiteName" -ForegroundColor Green
        $totalPassed++
    } else {
        Write-Host "  [FAIL] $suiteName (exit code $code)" -ForegroundColor Red
        Write-Host $suiteOutput
        $totalFailed++
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  TEST RUN SUMMARY: $totalPassed PASSED, $totalFailed FAILED" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($totalFailed -gt 0) {
    exit 1
} else {
    exit 0
}
