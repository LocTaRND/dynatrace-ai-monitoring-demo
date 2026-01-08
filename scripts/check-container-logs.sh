#!/bin/bash
# This script should be run inside the Azure App Service container via SSH

echo "=== OneAgent Log Monitoring Check ==="
echo ""

echo "1. Check if OneAgent is installed:"
if [ -d "/opt/dynatrace/oneagent" ]; then
    echo "✓ OneAgent directory exists"
    ls -la /opt/dynatrace/oneagent/
else
    echo "✗ OneAgent directory NOT found!"
fi
echo ""

echo "2. Check OneAgent process:"
ps aux | grep oneagent
echo ""

echo "3. Check environment variables:"
env | grep DT_ | sort
echo ""

echo "4. Check OneAgent logs:"
if [ -d "/opt/dynatrace/oneagent/log" ]; then
    echo "OneAgent log files:"
    ls -lh /opt/dynatrace/oneagent/log/
    echo ""
    echo "Latest OneAgent log (last 30 lines):"
    find /opt/dynatrace/oneagent/log -name "*.log" -type f | sort | tail -1 | xargs tail -30
else
    echo "✗ No OneAgent logs found"
fi
echo ""

echo "5. Check for log monitoring configuration:"
if [ -f "/opt/dynatrace/oneagent/agent/conf/ruxitagent.conf" ]; then
    echo "Checking agent configuration for log settings:"
    grep -i "log" /opt/dynatrace/oneagent/agent/conf/ruxitagent.conf | head -20
else
    echo "Agent configuration file not found"
fi
echo ""

echo "6. Check application stdout/stderr:"
echo "Recent application output:"
journalctl -u docker -n 50 2>/dev/null || tail -50 /var/log/docker.log 2>/dev/null || echo "Cannot access docker logs"
echo ""

echo "7. Test if logs are being written:"
echo "This is a test log from container" 
echo ""

echo "=== Check Complete ==="
echo ""
echo "If OneAgent is working correctly, you should:"
echo "- See oneagent processes running"
echo "- Have DT_LOGACCESS=true in environment"
echo "- See log monitoring configuration in agent conf"
echo "- Logs should appear in Dynatrace within 5-10 minutes"
