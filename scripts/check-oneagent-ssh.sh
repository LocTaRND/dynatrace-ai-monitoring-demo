#!/bin/bash
# Run this inside the SSH session of your Azure App Service

echo "=== Checking OneAgent Installation ==="
echo ""

echo "1. Check if OneAgent directory exists:"
ls -la /opt/dynatrace/ 2>/dev/null || echo "OneAgent directory not found!"
echo ""

echo "2. Check if OneAgent is installed:"
ls -la /opt/dynatrace/oneagent/agent/lib64/ 2>/dev/null || echo "OneAgent libraries not found!"
echo ""

echo "3. Check environment variables:"
echo "DT_ENDPOINT: $DT_ENDPOINT"
echo "DT_API_TOKEN: ${DT_API_TOKEN:0:20}..."
echo "DT_INCLUDE: $DT_INCLUDE"
echo "START_APP_CMD: $START_APP_CMD"
echo ""

echo "4. Check LD_PRELOAD:"
echo "LD_PRELOAD: $LD_PRELOAD"
echo ""

echo "5. Check running processes:"
ps aux | grep -E "dotnet|oneagent" | head -10
echo ""

echo "6. Check OneAgent logs:"
ls -la /opt/dynatrace/oneagent/log/ 2>/dev/null || echo "No OneAgent logs found!"
echo ""

echo "7. Test file existence:"
test -f /opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so && echo "✓ liboneagentproc.so EXISTS" || echo "✗ liboneagentproc.so NOT FOUND"
echo ""

echo "8. Check ldd dependencies:"
ldd /opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so 2>/dev/null || echo "Cannot check dependencies"
