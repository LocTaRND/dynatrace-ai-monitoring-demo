#!/bin/bash

#########################################
# Dynatrace Problem Simulation Script
# Generates various error scenarios
#########################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Get APP_URL from command line or use default
APP_URL="${1:-}"

if [ -z "$APP_URL" ]; then
    print_error "Usage: ./generate-problems.sh <app-url>"
    echo "Example: ./generate-problems.sh dynatrace-demo-api-12345.azurewebsites.net"
    exit 1
fi

# Remove https:// if provided
APP_URL="${APP_URL#https://}"
APP_URL="${APP_URL#http://}"

BASE_URL="https://$APP_URL"

echo "=========================================="
echo "  Dynatrace Problem Generator"
echo "=========================================="
echo ""
print_info "Target: $BASE_URL"
echo ""

#########################################
# Problem 1: High Error Rate (500 errors)
#########################################
print_info "Problem 1: Generating 500 Internal Server Errors..."
for i in {1..30}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/products/error/500")
    echo -n "."
    sleep 1
done
echo ""
print_warning "✓ Generated 30x 500 errors"
echo ""

#########################################
# Problem 2: Application Exceptions
#########################################
print_info "Problem 2: Triggering unhandled exceptions..."
for i in {1..20}; do
    curl -s "$BASE_URL/api/products/error/exception" > /dev/null 2>&1
    echo -n "."
    sleep 1
done
echo ""
print_warning "✓ Generated 20 exceptions"
echo ""

#########################################
# Problem 3: Slow Response Times
#########################################
print_info "Problem 3: Generating slow requests (10s each)..."
print_warning "This will take ~2 minutes..."
for i in {1..10}; do
    curl -s -m 15 "$BASE_URL/api/products/error/timeout" > /dev/null 2>&1 &
    echo -n "."
    sleep 12
done
wait
echo ""
print_warning "✓ Generated 10 slow requests"
echo ""

#########################################
# Problem 4: Database Connection Errors
#########################################
print_info "Problem 4: Simulating database connection failures..."
for i in {1..25}; do
    curl -s "$BASE_URL/api/products/error/database" > /dev/null 2>&1
    echo -n "."
    sleep 1
done
echo ""
print_warning "✓ Generated 25 database errors (503)"
echo ""

#########################################
# Problem 5: High CPU Usage
#########################################
print_info "Problem 5: Generating CPU-intensive operations..."
for i in {1..15}; do
    curl -s "$BASE_URL/api/products/error/cpu" > /dev/null 2>&1 &
    echo -n "."
    sleep 2
done
wait
echo ""
print_warning "✓ Generated 15 CPU-intensive operations"
echo ""

#########################################
# Problem 6: Memory Issues
#########################################
print_info "Problem 6: Triggering high memory allocation..."
for i in {1..10}; do
    curl -s "$BASE_URL/api/products/error/memory" > /dev/null 2>&1 &
    echo -n "."
    sleep 3
done
wait
echo ""
print_warning "✓ Generated 10 high-memory operations"
echo ""

#########################################
# Problem 7: 404 Not Found Errors
#########################################
print_info "Problem 7: Generating 404 errors..."
for i in {1..40}; do
    curl -s "$BASE_URL/api/products/99999" > /dev/null 2>&1
    echo -n "."
    sleep 0.5
done
echo ""
print_warning "✓ Generated 40x 404 errors"
echo ""

#########################################
# Problem 8: Mixed Load with Errors
#########################################
print_info "Problem 8: Generating mixed load (normal + errors)..."
for i in {1..50}; do
    # Random endpoint selection
    RAND=$((RANDOM % 10))
    case $RAND in
        0|1|2) curl -s "$BASE_URL/api/health" > /dev/null 2>&1 ;;
        3|4) curl -s "$BASE_URL/api/products" > /dev/null 2>&1 ;;
        5) curl -s "$BASE_URL/api/products/error/500" > /dev/null 2>&1 ;;
        6) curl -s "$BASE_URL/api/products/error/exception" > /dev/null 2>&1 ;;
        7) curl -s "$BASE_URL/api/products/error/database" > /dev/null 2>&1 ;;
        8) curl -s "$BASE_URL/api/products/99999" > /dev/null 2>&1 ;;
        9) curl -s "$BASE_URL/api/products/error/cpu" > /dev/null 2>&1 ;;
    esac
    echo -n "."
    sleep 0.5
done
echo ""
print_warning "✓ Generated 50 mixed requests"
echo ""

echo "=========================================="
echo "  Problem Generation Complete!"
echo "=========================================="
echo ""
print_info "What was simulated:"
echo "  • 30x HTTP 500 errors"
echo "  • 20x Unhandled exceptions"
echo "  • 10x Slow requests (10s timeout)"
echo "  • 25x Database connection failures (503)"
echo "  • 15x High CPU operations"
echo "  • 10x High memory allocations"
echo "  • 40x HTTP 404 errors"
echo "  • 50x Mixed load"
echo ""
print_info "Expected Dynatrace Problems:"
echo "  ⚠️  High error rate"
echo "  ⚠️  Slow response time"
echo "  ⚠️  Exception increase"
echo "  ⚠️  Service unavailability"
echo "  ⚠️  Resource contention"
echo ""
print_warning "⏰ Wait 5-15 minutes for problems to appear in Dynatrace"
echo ""
print_info "Check problems at:"
echo "  https://[your-tenant].live.dynatrace.com/ui/problems"
echo ""
print_info "To generate more problems, run:"
echo "  ./generate-problems.sh $APP_URL"
echo ""
