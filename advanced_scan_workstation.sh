#!/bin/bash

# Ubuntu Workstation Scanner Script (2024, Ubuntu 24.04 LTS)
# Scans for system, security, network, and hardware issues; generates text, HTML, and JSON reports
# Run with sudo: sudo ./advanced_scan_workstation.sh

# Exit on error
set -e

# Log function
log() {
    echo "[INFO] $1"
}

# Warning function
warning() {
    echo "[WARNING] $1" >&2
    echo "[WARNING] $1" >> "$REPORT_FILE"
    echo "{\"level\": \"warning\", \"message\": \"$1\"}" >> "$JSON_REPORT"
}

# Error function
error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
fi

# Output files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="/tmp/workstation_scan_report_$TIMESTAMP.txt"
HTML_REPORT="/tmp/workstation_scan_report_$TIMESTAMP.html"
JSON_REPORT="/tmp/workstation_scan_report_$TIMESTAMP.json"
log "Generating reports at $REPORT_FILE, $HTML_REPORT, and $JSON_REPORT"

# Initialize reports
{
    echo "Advanced Ubuntu Workstation Scan Report"
    echo "Generated on: $(date)"
    echo "====================================="
    echo ""
} > "$REPORT_FILE"

{
    echo "<!DOCTYPE html><html><head><title>Workstation Scan Report</title>"
    echo "<style>body {font-family: Arial, sans-serif; margin: 20px; line-height: 1.6;}"
    echo "h1 {color: #2c3e50;} h2 {color: #34495e; border-bottom: 1px solid #ddd;}"
    echo "table {border-collapse: collapse; width: 100%; margin: 10px 0;}"
    echo "th, td {border: 1px solid #ddd; padding: 10px; text-align: left;}"
    echo "th {background-color: #ecf0f1; color: #2c3e50;}"
    echo ".warning {color: #e74c3c; font-weight: bold;}"
    echo "pre {background: #f8f8f8; padding: 10px; border-radius: 4px;}"
    echo "</style></head><body><h1>Workstation Scan Report</h1>"
    echo "<p>Generated on: $(date)</p><hr>"
} > "$HTML_REPORT"

{
    echo "{\"scan_time\": \"$(date)\", \"results\": []}"
} > "$JSON_REPORT"

# Install required tools if missing
log "Checking for required tools..."
TOOLS="lynis clamav lm-sensors smartmontools sysstat net-tools jq"
for tool in $TOOLS; do
    if ! dpkg -l | grep -q "$tool"; then
        log "Installing $tool..."
        apt update && apt install -y "$tool" || warning "Failed to install $tool"
    fi
done

# 1. System Information
log "Collecting system information..."
{
    echo "System Information"
    echo "------------------"
    echo "OS Version: $(lsb_release -a 2>/dev/null | grep Description | cut -f2-)"
    echo "Kernel: $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Last Reboot: $(who -b | awk '{print $3, $4}')"
    echo "Systemd Version: $(systemctl --version | head -n 1)"
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>System Information</h2><table>"
    echo "<tr><th>Parameter</th><th>Value</th></tr>"
    echo "<tr><td>OS Version</td><td>$(lsb_release -a 2>/dev/null | grep Description | cut -f2-)</td></tr>"
    echo "<tr><td>Kernel</td><td>$(uname -r)</td></tr>"
    echo "<tr><td>Hostname</td><td>$(hostname)</td></tr>"
    echo "<tr><td>Uptime</td><td>$(uptime -p)</td></tr>"
    echo "<tr><td>Last Reboot</td><td>$(who -b | awk '{print $3, $4}')</td></tr>"
    echo "<tr><td>Systemd Version</td><td>$(systemctl --version | head -n 1)</td></tr>"
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"System Information\", \"details\": {\"OS Version\": \"$(lsb_release -a 2>/dev/null | grep Description | cut -f2-)\", \"Kernel\": \"$(uname -r)\", \"Hostname\": \"$(hostname)\", \"Uptime\": \"$(uptime -p)\", \"Last Reboot\": \"$(who -b | awk '{print $3, $4}')\", \"Systemd Version\": \"$(systemctl --version | head -n 1)\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 2. Package Status
log "Checking package status..."
{
    echo "Package Status"
    echo "------------------"
    apt update >/dev/null || warning "Failed to update package lists"
    UPGRADEABLE=$(apt list --upgradable 2>/dev/null | grep -v Listing | wc -l)
    if [ "$UPGRADEABLE" -gt 0 ]; then
        warning "$UPGRADEABLE packages can be upgraded. Run 'sudo apt upgrade'."
        echo "$UPGRADEABLE packages can be upgraded" >> "$REPORT_FILE"
    else
        echo "All packages are up to date" >> "$REPORT_FILE"
    fi
    # Security updates
    apt list --upgradable 2>/dev/null | grep -i security > /tmp/security_updates.txt
    if [ -s /tmp/security_updates.txt ]; then
        warning "Security updates are available"
        echo "Security updates available:" >> "$REPORT_FILE"
        cat /tmp/security_updates.txt >> "$REPORT_FILE"
    else
        echo "No security updates pending" >> "$REPORT_FILE"
    fi
    rm -f /tmp/security_updates.txt
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Package Status</h2><table>"
    echo "<tr><th>Status</th><th>Details</th></tr>"
    if [ "$UPGRADEABLE" -gt 0 ]; then
        echo "<tr><td class='warning'>Upgradable Packages</td><td>$UPGRADEABLE packages can be upgraded</td></tr>"
    else
        echo "<tr><td>Upgradable Packages</td><td>All packages are up to date</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Package Status\", \"details\": {\"Upgradable Packages\": \"$UPGRADEABLE\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 3. Broken Dependencies
log "Checking for broken dependencies..."
{
    echo "Broken Dependencies"
    echo "------------------"
    if ! apt check >/dev/null 2>&1; then
        warning "Broken dependencies detected. Run 'sudo apt --fix-broken install'."
        echo "Broken dependencies detected" >> "$REPORT_FILE"
    else
        echo "No broken dependencies found" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Broken Dependencies</h2><table>"
    if ! apt check >/dev/null 2>&1; then
        echo "<tr><td class='warning'>Status</td><td>Broken dependencies detected</td></tr>"
    else
        echo "<tr><td>Status</td><td>No broken dependencies found</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Broken Dependencies\", \"details\": {\"Status\": \"$(apt check >/dev/null 2>&1 && echo 'No broken dependencies' || echo 'Broken dependencies detected')\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 4. Disk Usage and Health
log "Checking disk usage and health..."
{
    echo "Disk Usage and Health"
    echo "------------------"
    echo "Disk Usage:" >> "$REPORT_FILE"
    df -h >> "$REPORT_FILE"
    HIGH_USAGE=$(df -h | grep -v Filesystem | awk '$5 > 90' | wc -l)
    if [ "$HIGH_USAGE" -gt 0 ]; then
        warning "High disk usage detected on some partitions (>90%)"
    fi
    echo "Disk Health:" >> "$REPORT_FILE"
    for disk in /dev/nvme[0-9]n[1-9] /dev/sd[a-z]; do
        if [ -b "$disk" ]; then
            smartctl -H "$disk" 2>/dev/null | grep -i "result" >> "$REPORT_FILE" || true
        fi
    done
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Disk Usage and Health</h2><table>"
    echo "<tr><th>Parameter</th><th>Details</th></tr>"
    echo "<tr><td>Disk Usage</td><td><pre>$(df -h)</pre></td></tr>"
    if [ "$HIGH_USAGE" -gt 0 ]; then
        echo "<tr><td class='warning'>High Usage</td><td>Some partitions >90% full</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Disk Usage and Health\", \"details\": {\"High Usage\": \"$HIGH_USAGE partitions >90%\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 5. Memory and Processes
log "Checking memory and processes..."
{
    echo "Memory and Processes"
    echo "------------------"
    echo "Memory Usage:" >> "$REPORT_FILE"
    free -m >> "$REPORT_FILE"
    TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
    USED_MEM=$(free -m | grep Mem | awk '{print $3}')
    PERCENT_USED=$((USED_MEM * 100 / TOTAL_MEM))
    if [ "$PERCENT_USED" -gt 90 ]; then
        warning "High memory usage detected ($PERCENT_USED%)"
    fi
    echo "Top 5 CPU Processes:" >> "$REPORT_FILE"
    ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n 6 >> "$REPORT_FILE"
    echo "Top 5 Memory Processes:" >> "$REPORT_FILE"
    ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%mem | head -n 6 >> "$REPORT_FILE"
    ZOMBIES=$(ps aux | grep ' Z ' | wc -l)
    if [ "$ZOMBIES" -gt 0 ]; then
        warning "$ZOMBIES zombie processes detected"
        echo "$ZOMBIES zombie processes detected" >> "$REPORT_FILE"
    fi
    echo "I/O Performance:" >> "$REPORT_FILE"
    iostat -x 1 2 >> "$REPORT_FILE" 2>/dev/null || warning "iostat failed"
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Memory and Processes</h2><table>"
    echo "<tr><th>Parameter</th><th>Details</th></tr>"
    echo "<tr><td>Memory Usage</td><td><pre>$(free -m)</pre></td></tr>"
    if [ "$PERCENT_USED" -gt 90 ]; then
        echo "<tr><td class='warning'>High Usage</td><td>Memory usage at $PERCENT_USED%</td></tr>"
    fi
    echo "<tr><td>Top CPU Processes</td><td><pre>$(ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n 6)</pre></td></tr>"
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Memory and Processes\", \"details\": {\"Memory Usage\": \"$PERCENT_USED%\", \"Zombies\": \"$ZOMBIES\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 6. CPU Load and Temperature
log "Checking CPU load and temperature..."
{
    echo "CPU Load and Temperature"
    echo "------------------"
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1, $2, $3}')
    echo "Load Average (1/5/15 min): $LOAD_AVG" >> "$REPORT_FILE"
    LOAD_1MIN=$(echo "$LOAD_AVG" | awk '{print $1}' | cut -d. -f1)
    if [ "$LOAD_1MIN" -gt 4 ]; then
        warning "High CPU load detected"
    fi
    if sensors >/dev/null 2>&1; then
        echo "CPU Temperature:" >> "$REPORT_FILE"
        sensors | grep -i "core" >> "$REPORT_FILE" || true
    else
        warning "Temperature sensors not detected. Install lm-sensors."
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>CPU Load and Temperature</h2><table>"
    echo "<tr><th>Parameter</th><th>Details</th></tr>"
    echo "<tr><td>Load Average</td><td>$LOAD_AVG</td></tr>"
    if sensors >/dev/null 2>&1; then
        echo "<tr><td>Temperature</td><td><pre>$(sensors | grep -i "core")</pre></td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"CPU Load and Temperature\", \"details\": {\"Load Average\": \"$LOAD_AVG\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 7. Systemd Services and Timers
log "Checking systemd services and timers..."
{
    echo "Systemd Services and Timers"
    echo "------------------"
    FAILED_SERVICES=$(systemctl --failed | grep "loaded.*failed" || true)
    if [ -n "$FAILED_SERVICES" ]; then
        warning "Failed systemd services detected"
        echo "Failed Services:" >> "$REPORT_FILE"
        echo "$FAILED_SERVICES" >> "$REPORT_FILE"
    else
        echo "No failed services detected" >> "$REPORT_FILE"
    fi
    FAILED_TIMERS=$(systemctl list-timers --all | grep "failed" || true)
    if [ -n "$FAILED_TIMERS" ]; then
        warning "Failed systemd timers detected"
        echo "Failed Timers:" >> "$REPORT_FILE"
        echo "$FAILED_TIMERS" >> "$REPORT_FILE"
    else
        echo "No failed timers detected" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Systemd Services and Timers</h2><table>"
    if [ -n "$FAILED_SERVICES" ]; then
        echo "<tr><td class='warning'>Failed Services</td><td><pre>$FAILED_SERVICES</pre></td></tr>"
    else
        echo "<tr><td>Failed Services</td><td>No failed services detected</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Systemd Services and Timers\", \"details\": {\"Failed Services\": \"$(echo "$FAILED_SERVICES" | wc -l)\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 8. Log Analysis
log "Checking system logs..."
{
    echo "System Log Analysis"
    echo "------------------"
    for log in "journalctl -p 3 -b" "/var/log/auth.log" "/var/log/dpkg.log"; do
        if [[ "$log" == journalctl* ]]; then
            echo "Recent errors in journalctl (priority 3):" >> "$REPORT_FILE"
            $log | tail -n 50 >> "$REPORT_FILE" || echo "No errors found" >> "$REPORT_FILE"
        elif [ -f "$log" ]; then
            echo "Recent errors in $log:" >> "$REPORT_FILE"
            tail -n 100 "$log" | grep -i "error\|failed\|critical" >> "$REPORT_FILE" || echo "No errors found" >> "$REPORT_FILE"
        else
            warning "$log not found"
        fi
    done
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>System Log Analysis</h2><table>"
    for log in "journalctl -p 3 -b" "/var/log/auth.log" "/var/log/dpkg.log"; do
        if [[ "$log" == journalctl* ]]; then
            ERRORS=$(eval "$log | tail -n 50" || echo "No errors found")
            echo "<tr><td>Journalctl</td><td><pre>$ERRORS</pre></td></tr>"
        elif [ -f "$log" ]; then
            ERRORS=$(tail -n 100 "$log" | grep -i "error\|failed\|critical" || echo "No errors found")
            echo "<tr><td>$log</td><td><pre>$ERRORS</pre></td></tr>"
        fi
    done
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"System Log Analysis\", \"details\": {\"Logs Checked\": \"journalctl, auth.log, dpkg.log\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 9. Security Checks
log "Performing security checks..."
{
    echo "Security Checks"
    echo "------------------"
    echo "World-Writable Files:" >> "$REPORT_FILE"
    WW_FILES=$(find / -perm -2 -type f 2>/dev/null | head -n 10)
    if [ -n "$WW_FILES" ]; then
        warning "World-writable files detected"
        echo "$WW_FILES" >> "$REPORT_FILE"
    else
        echo "No world-writable files found" >> "$REPORT_FILE"
    fi
    echo "Lynis Security Scan:" >> "$REPORT_FILE"
    lynis audit system --quick > /tmp/lynis_scan.txt 2>/dev/null
    grep -i "warning\|suggestion" /tmp/lynis_scan.txt >> "$REPORT_FILE" || echo "No issues found by Lynis" >> "$REPORT_FILE"
    echo "ClamAV Malware Scan:" >> "$REPORT_FILE"
    freshclam >/dev/null 2>&1 || warning "Failed to update ClamAV signatures"
    clamscan -r /home --bell -i > /tmp/clamav_scan.txt 2>/dev/null
    grep -i "infected" /tmp/clamav_scan.txt >> "$REPORT_FILE" || echo "No malware detected" >> "$REPORT_FILE"
    echo "Firewall Status:" >> "$REPORT_FILE"
    if ! ufw status >/dev/null 2>&1; then
        warning "UFW is not installed or not enabled"
        echo "UFW is not installed or not enabled" >> "$REPORT_FILE"
    else
        ufw status >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Security Checks</h2><table>"
    echo "<tr><th>Check</th><th>Details</th></tr>"
    if [ -n "$WW_FILES" ]; then
        echo "<tr><td class='warning'>World-Writable Files</td><td><pre>$WW_FILES</pre></td></tr>"
    else
        echo "<tr><td>World-Writable Files</td><td>No world-writable files found</td></tr>"
    fi
    echo "<tr><td>Lynis Scan</td><td><pre>$(grep -i "warning\|suggestion" /tmp/lynis_scan.txt || echo "No issues found")</pre></td></tr>"
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Security Checks\", \"details\": {\"World-Writable Files\": \"$(echo "$WW_FILES" | wc -l)\", \"Lynis Issues\": \"$(grep -i "warning\|suggestion" /tmp/lynis_scan.txt | wc -l)\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"
rm -f /tmp/lynis_scan.txt /tmp/clamav_scan.txt

# 10. Network Diagnostics
log "Checking network status..."
{
    echo "Network Diagnostics"
    echo "------------------"
    echo "Network Interfaces:" >> "$REPORT_FILE"
    ip addr >> "$REPORT_FILE"
    echo "Open Ports:" >> "$REPORT_FILE"
    ss -tuln >> "$REPORT_FILE" 2>/dev/null || warning "ss failed"
    echo "DNS Resolution:" >> "$REPORT_FILE"
    if nslookup google.com >/dev/null 2>&1; then
        echo "DNS resolution successful" >> "$REPORT_FILE"
    else
        warning "DNS resolution failed"
        echo "DNS resolution failed" >> "$REPORT_FILE"
    fi
    echo "Ping Test (google.com):" >> "$REPORT_FILE"
    if ping -c 4 google.com >/dev/null 2>&1; then
        echo "Ping successful" >> "$REPORT_FILE"
    else
        warning "Ping to google.com failed"
        echo "Ping failed" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Network Diagnostics</h2><table>"
    echo "<tr><th>Parameter</th><th>Details</th></tr>"
    echo "<tr><td>Interfaces</td><td><pre>$(ip addr)</pre></td></tr>"
    echo "<tr><td>Open Ports</td><td><pre>$(ss -tuln)</pre></td></tr>"
    if nslookup google.com >/dev/null 2>&1; then
        echo "<tr><td>DNS Resolution</td><td>Successful</td></tr>"
    else
        echo "<tr><td class='warning'>DNS Resolution</td><td>Failed</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Network Diagnostics\", \"details\": {\"DNS Resolution\": \"$(nslookup google.com >/dev/null 2>&1 && echo 'Successful' || echo 'Failed')\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# 11. Docker Container Status (if applicable)
log "Checking Docker containers..."
{
    echo "Docker Container Status"
    echo "------------------"
    if command -v docker >/dev/null 2>&1; then
        STOPPED_CONTAINERS=$(docker ps -a -q -f status=exited | wc -l)
        if [ "$STOPPED_CONTAINERS" -gt 0 ]; then
            warning "$STOPPED_CONTAINERS stopped Docker containers detected"
            echo "$STOPPED_CONTAINERS stopped containers detected" >> "$REPORT_FILE"
            echo "Stopped containers:" >> "$REPORT_FILE"
            docker ps -a -f status=exited >> "$REPORT_FILE"
        else
            echo "No stopped containers detected" >> "$REPORT_FILE"
        fi
    else
        echo "Docker not installed" >> "$REPORT_FILE"
    fi
    echo ""
} >> "$REPORT_FILE"
{
    echo "<h2>Docker Container Status</h2><table>"
    if command -v docker >/dev/null 2>&1 && [ "$STOPPED_CONTAINERS" -gt 0 ]; then
        echo "<tr><td class='warning'>Stopped Containers</td><td><pre>$(docker ps -a -f status=exited)</pre></td></tr>"
    else
        echo "<tr><td>Status</td><td>$(command -v docker >/dev/null 2>&1 && echo 'No stopped containers detected' || echo 'Docker not installed')</td></tr>"
    fi
    echo "</table>"
} >> "$HTML_REPORT"
{
    jq ".results += [{\"section\": \"Docker Container Status\", \"details\": {\"Stopped Containers\": \"$STOPPED_CONTAINERS\"}}]" "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to update JSON report"

# Finalize reports
log "Scan completed."
{
    echo "====================================="
    echo "Scan completed on: $(date)"
    echo "Review warnings above and check reports for details"
} >> "$REPORT_FILE"
{
    echo "<hr><p>Scan completed on: $(date)</p></body></html>"
} >> "$HTML_REPORT"
{
    jq . "$JSON_REPORT" > tmp.json && mv tmp.json "$JSON_REPORT"
} || warning "Failed to finalize JSON report"

# Display warnings summary
echo ""
echo "Summary of Issues:"
grep -E "\[WARNING\]" /dev/stderr | sed 's/\[WARNING\]/  -/'
echo ""
echo "Text report: $REPORT_FILE"
echo "HTML report: $HTML_REPORT"
echo "JSON report: $JSON_REPORT"
