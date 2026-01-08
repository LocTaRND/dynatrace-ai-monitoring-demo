# Dynatrace Problem Simulation Script (PowerShell)
# Generates various error scenarios

param(
    [Parameter(Mandatory=$true)]
    [string]$AppUrl
)

# Remove protocol if provided
$AppUrl = $AppUrl -replace '^https?://', ''
$BaseUrl = "https://$AppUrl"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Dynatrace Problem Generator" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Target: $BaseUrl" -ForegroundColor Green
Write-Host ""

# Problem 1: High Error Rate
Write-Host "[INFO] Problem 1: Generating 500 errors..." -ForegroundColor Green
1..30 | ForEach-Object {
    try { Invoke-WebRequest -Uri "$BaseUrl/api/products/error/500" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 1000
}
Write-Host ""
Write-Host "[WARN] ✓ Generated 30x 500 errors" -ForegroundColor Yellow
Write-Host ""

# Problem 2: Exceptions
Write-Host "[INFO] Problem 2: Triggering exceptions..." -ForegroundColor Green
1..20 | ForEach-Object {
    try { Invoke-WebRequest -Uri "$BaseUrl/api/products/error/exception" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 1000
}
Write-Host ""
Write-Host "[WARN] ✓ Generated 20 exceptions" -ForegroundColor Yellow
Write-Host ""

# Problem 3: Slow Requests
Write-Host "[INFO] Problem 3: Generating slow requests..." -ForegroundColor Green
Write-Host "[WARN] This will take ~2 minutes..." -ForegroundColor Yellow
$jobs = 1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        try { Invoke-WebRequest -Uri "$url/api/products/error/timeout" -TimeoutSec 15 -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    } -ArgumentList $BaseUrl
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 12000
}
$jobs | Wait-Job | Remove-Job
Write-Host ""
Write-Host "[WARN] ✓ Generated 10 slow requests" -ForegroundColor Yellow
Write-Host ""

# Problem 4: Database Errors
Write-Host "[INFO] Problem 4: Simulating database failures..." -ForegroundColor Green
1..25 | ForEach-Object {
    try { Invoke-WebRequest -Uri "$BaseUrl/api/products/error/database" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 1000
}
Write-Host ""
Write-Host "[WARN] ✓ Generated 25 database errors" -ForegroundColor Yellow
Write-Host ""

# Problem 5: CPU Load
Write-Host "[INFO] Problem 5: Generating CPU load..." -ForegroundColor Green
$jobs = 1..15 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        try { Invoke-WebRequest -Uri "$url/api/products/error/cpu" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    } -ArgumentList $BaseUrl
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 2000
}
$jobs | Wait-Job | Remove-Job
Write-Host ""
Write-Host "[WARN] ✓ Generated 15 CPU operations" -ForegroundColor Yellow
Write-Host ""

# Problem 6: Memory Load
Write-Host "[INFO] Problem 6: Triggering high memory..." -ForegroundColor Green
$jobs = 1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        try { Invoke-WebRequest -Uri "$url/api/products/error/memory" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    } -ArgumentList $BaseUrl
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 3000
}
$jobs | Wait-Job | Remove-Job
Write-Host ""
Write-Host "[WARN] ✓ Generated 10 memory operations" -ForegroundColor Yellow
Write-Host ""

# Problem 7: 404 Errors
Write-Host "[INFO] Problem 7: Generating 404 errors..." -ForegroundColor Green
1..40 | ForEach-Object {
    try { Invoke-WebRequest -Uri "$BaseUrl/api/products/99999" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 500
}
Write-Host ""
Write-Host "[WARN] ✓ Generated 40x 404 errors" -ForegroundColor Yellow
Write-Host ""

# Problem 8: Mixed Load
Write-Host "[INFO] Problem 8: Generating mixed load..." -ForegroundColor Green
1..50 | ForEach-Object {
    $rand = Get-Random -Minimum 0 -Maximum 10
    $endpoint = switch ($rand) {
        {$_ -in 0,1,2} { "/api/health" }
        {$_ -in 3,4} { "/api/products" }
        5 { "/api/products/error/500" }
        6 { "/api/products/error/exception" }
        7 { "/api/products/error/database" }
        8 { "/api/products/99999" }
        9 { "/api/products/error/cpu" }
    }
    try { Invoke-WebRequest -Uri "$BaseUrl$endpoint" -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 500
}
Write-Host ""
Write-Host "[WARN] ✓ Generated 50 mixed requests" -ForegroundColor Yellow
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Problem Generation Complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] What was simulated:" -ForegroundColor Green
Write-Host "  • 30x HTTP 500 errors"
Write-Host "  • 20x Unhandled exceptions"
Write-Host "  • 10x Slow requests"
Write-Host "  • 25x Database failures"
Write-Host "  • 15x High CPU operations"
Write-Host "  • 10x High memory allocations"
Write-Host "  • 40x HTTP 404 errors"
Write-Host "  • 50x Mixed load"
Write-Host ""
Write-Host "[INFO] Expected Dynatrace Problems:" -ForegroundColor Green
Write-Host "  ⚠️  High error rate" -ForegroundColor Yellow
Write-Host "  ⚠️  Slow response time" -ForegroundColor Yellow
Write-Host "  ⚠️  Exception increase" -ForegroundColor Yellow
Write-Host "  ⚠️  Service unavailability" -ForegroundColor Yellow
Write-Host ""
Write-Host "[WARN] ⏰ Wait 5-15 minutes for problems to appear" -ForegroundColor Yellow
Write-Host ""
Write-Host "[INFO] To run again:" -ForegroundColor Green
Write-Host "  .\generate-problems.ps1 -AppUrl $AppUrl"
Write-Host ""
