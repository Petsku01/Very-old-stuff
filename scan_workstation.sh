#!/bin/bash

# Ubuntu Workstation Scanner Script (2013, Ubuntu 12.04/13.04)
# Scans for common workstation problems and generates a report
# Run with sudo for full access: sudo ./scan_workstation.sh

# Exit on error
set -e

# Log function for better output
log() {
    echo "[INFO] $1"
}

# Warning function for issues
warning() {
    echo "[WARNING] $1" >&2
}

# Error function for critical failures
error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
fi

# Output report file
REPORT_FILE="/tmp/workstation_scan_report_$(date +%Y%m%d_%H%M%S).txt"
log "Generating report at $REPORT_FILE"

# Start report
echo "Ubuntu Workstation Scan Report" > "$REPORT_FILE"
echo "Generated on: $(date)" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. System Information
log "Collecting system information..."
{
    echo "System Information"
    echo "------------------"
    echo "OS Version: $(lsb_release -a 2>/dev/null | grep Description | cut -f2-)"
    echo "Kernel: $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo ""
} >> "$REPORT_FILE"

# 2. Check for outdated packages
log "Checking for outdated packages..."
{
    echo "Package Status"
    echo "------------------"
    apt-get update >/dev/null || warning "Failed to update package lists"
    UPGRADEABLE=$(apt-get -s upgrade | grep -E "^Inst" | wc -l)
    if [ "$UPGRADEABLE" -gt 0 ]; then
        warning "$UPGRADEABLE packages can be upgraded. Run 'sudo apt-get upgrade' to update."
        echo "$UPGRADEABLE packages can be upgraded" >> "$REPORT_FILE"
    else
        echo "All packages are up to date" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"

# 3. Check for broken dependencies
log "Checking for broken dependencies..."
{
    echo "Broken Dependencies"
    echo "------------------"
    if ! apt-get check >/dev/null 2>&1; then
        warning "Broken dependencies detected. Run 'sudo apt-get -f install' to fix."
        echo "Broken dependencies detected" >> "$REPORT_FILE"
    else
        echo "No broken dependencies found" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"

# 4. Check disk usage
log "Checking disk usage..."
{
    echo "Disk Usage"
    echo "------------------"
    df -h >> "$REPORT_FILE"
    HIGH_USAGE=$(df -h | grep -v Filesystem | awk '$5 > 90' | wc -l)
    if [ "$HIGH_USAGE" -gt 0 ]; then
        warning "High disk usage detected on some partitions (>90%)"
    fi
    echo ""
} >> "$REPORT_FILE"

# 5. Check memory usage
log "Checking memory usage..."
{
    echo "Memory Usage"
    echo "------------------"
    free -m >> "$REPORT_FILE"
    TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
    USED_MEM=$(free -m | grep Mem | awk '{print $3}')
    PERCENT_USED=$((USED_MEM * 100 / TOTAL_MEM))
    if [ "$PERCENT_USED" -gt 90 ]; then
        warning "High memory usage detected ($PERCENT_USED%)"
    fi
    echo ""
} >> "$REPORT_FILE"

# 6. Check CPU load
log "Checking CPU load..."
{
    echo "CPU Load"
    echo "------------------"
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1, $2, $3}')
    echo "Load Average (1/5/15 min): $LOAD_AVG" >> "$REPORT_FILE"
    LOAD_1MIN=$(echo "$LOAD_AVG" | awk '{print $1}' | cut -d. -f1)
    if [ "$LOAD_1MIN" -gt 4 ]; then
        warning "High CPU load detected"
    fi
    echo ""
} >> "$REPORT_FILE"

# 7. Check for failed services
log "Checking for failed services..."
{
    echo "Service Status"
    echo "------------------"
    FAILED_SERVICES=$(service --status-all 2>&1 | grep -E "not running|failed" || true)
    if [ -n "$FAILED_SERVICES" ]; then
        warning "Failed or stopped services detected"
        echo "$FAILED_SERVICES" >> "$REPORT_FILE"
    else
        echo "No failed services detected" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"

# 8. Check system logs for errors
log "Checking system logs for errors..."
{
    echo "System Log Errors (last 100 lines)"
    echo "------------------"
    ERRORS=$(tail -n 100 /var/log/syslog | grep -i "error\|failed\|critical" || true)
    if [ -n "$ERRORS" ]; then
        warning "Errors found in system logs"
        echo "$ERRORS" >> "$REPORT_FILE"
    else
        echo "No recent errors found in logs" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"

# 9. Check firewall status
log "Checking firewall status..."
{
    echo "Firewall Status"
    echo "------------------"
    if ! ufw status >/dev/null 2>&1; then
        warning "UFW is not installed or not enabled"
        echo "UFW is not installed or not enabled" >> "$REPORT_FILE"
    else
        ufw status >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"

# 10. Check for security updates
log "Checking for security updates..."
{
    echo "Security Updates"
    echo "------------------"
    apt-get -s upgrade | grep -i security > /tmp/security_updates.txt
    if [ -s /tmp/security_updates.txt ]; then
        warning "Security updates are available"
        cat /tmp/security_updates.txt >> "$REPORT_FILE"
    else
        echo "No security updates pending" >> "$REPORT_FILE"
    fi
    rm -f /tmp/security_updates.txt
    echo ""
} >> "$REPORT_FILE"

# Finalize report
log "Scan completed. Report saved to $REPORT_FILE"
{
    echo "====================================="
    echo "Scan completed on: $(date)"
    echo "Review warnings above and check $REPORT_FILE for details"
} >> "$REPORT_FILE"

# Display warnings summary
echo ""
echo "Summary of Issues:"
grep -E "\[WARNING\]" /dev/stderr | sed 's/\[WARNING\]/  -/'
echo ""
echo "Full report available at $REPORT_FILE"
