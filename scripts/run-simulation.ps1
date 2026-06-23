<#
.SYNOPSIS
    ECBS production simulation harness (Fase 16).

.DESCRIPTION
    Loads a production-scale synthetic portfolio, runs the complete nightly
    batch over it, and measures wall-clock time, container memory and
    throughput. Expects the stack to be running (docker compose up -d).

.PARAMETER Customers / Accounts / Transactions / Cards / Loans
    Volumes to generate. Defaults are the Fase 16 production targets.

.EXAMPLE
    docker compose up -d
    ./scripts/run-simulation.ps1
#>
param(
    [int]$Customers    = 100000,
    [int]$Accounts     = 500000,
    [int]$Transactions = 5000000,
    [int]$Cards        = 10000,
    [int]$Loans        = 5000,
    [string]$Postgres  = "ecbs-postgres",
    [string]$Cobol     = "ecbs-cobol-runtime"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$report = Join-Path $root "docs/fase16-results.txt"

function Mem($container) {
    (docker stats --no-stream --format "{{.MemUsage}}" $container) -replace "`r",""
}

function Section($t) { Write-Output ""; Write-Output "==================== $t ====================" }

$lines = @()
$lines += "ECBS - Fase 16 production simulation"
$lines += "Run at: $(Get-Date -Format o)"
$lines += "Targets: customers=$Customers accounts=$Accounts transactions=$Transactions cards=$Cards loans=$Loans"
$lines += ""

# ---- 1. Bulk data load -------------------------------------------------
Section "1. Bulk data load"
$memDbBefore = Mem $Postgres
$sql = Get-Content -Raw (Join-Path $root "scripts/simulation-load.sql")
$loadTime = Measure-Command {
    $sql | docker exec -i $Postgres psql -U ecbs_admin -d ecbs `
        -v customers=$Customers -v accounts=$Accounts -v transactions=$Transactions `
        -v cards=$Cards -v loans=$Loans -q -f -
}
$memDbAfter = Mem $Postgres
$totalRows = $Customers + $Accounts + $Transactions + $Cards + $Loans
$loadSec = [math]::Round($loadTime.TotalSeconds, 1)
$loadThrough = [math]::Round($totalRows / $loadTime.TotalSeconds, 0)
$lines += "1. BULK DATA LOAD"
$lines += "   rows inserted : $totalRows"
$lines += "   wall time     : $loadSec s"
$lines += "   throughput    : $loadThrough rows/s"
$lines += "   postgres mem  : $memDbBefore -> $memDbAfter"
Write-Output "Loaded $totalRows rows in $loadSec s ($loadThrough rows/s)"

# ---- 2. Complete nightly batch ----------------------------------------
Section "2. Complete nightly batch (BATCH-NIGHTLY)"
$memCobolBefore = Mem $Cobol
# Run the batch binary directly inside the container so the run is not
# bounded by the bridge HTTP timeout; this is the same program the bridge
# invokes.
$batchOut = ""
$batchTime = Measure-Command {
    $batchOut = docker exec $Cobol sh -c 'printf ''{"user":"sim"}'' | /opt/ecbs/bin/BATCH-NIGHTLY'
}
$memCobolAfter = Mem $Cobol
$batchJson = ($batchOut | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
$batchSec = [math]::Round($batchTime.TotalSeconds, 1)
$processed = 0
if ($batchJson -match '"processed":(\d+)') { $processed = [int]$Matches[1] }
$batchThrough = if ($batchTime.TotalSeconds -gt 0) { [math]::Round($processed / $batchTime.TotalSeconds, 0) } else { 0 }
$lines += ""
$lines += "2. COMPLETE NIGHTLY BATCH"
$lines += "   result        : $batchJson"
$lines += "   processed      : $processed accounts/operations"
$lines += "   wall time     : $batchSec s"
$lines += "   throughput    : $batchThrough ops/s"
$lines += "   cobol mem     : $memCobolBefore -> $memCobolAfter"
Write-Output "Batch processed $processed ops in $batchSec s ($batchThrough ops/s)"
Write-Output $batchJson

# ---- 3. Persist report -------------------------------------------------
$lines | Set-Content -Encoding utf8 $report
Section "Report written"
Write-Output $report
