#!/bin/bash
# Advanced Ubuntu Workstation Scanner (2025 – tested on Ubuntu 24.04 LTS)
# Generates clean TXT, HTML, and valid JSON reports
# Run with: sudo ./workstation_scanner.sh

set -euo pipefail
IFS=$'\n\t'

# Colors for console output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths and timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE="/tmp"
REPORT_TXT="${BASE}/workstation_scan_${TIMESTAMP}.txt"
REPORT_HTML="${BASE}/workstation_scan_${TIMESTAMP}.html"
REPORT_JSON="${BASE}/workstation_scan_${TIMESTAMP}.json"

# Temporary files
TEMP_FILES=()

cleanup() {
    rm -f "${TEMP_FILES[@]}" 2>/dev/null || true
}
trap cleanup EXIT

log()    { echo -e "[INFO] $1"; }
warn()   { echo -e "${YELLOW}[WARNING] $1${NC}" >&2; echo "WARNING: $1" >> "$REPORT_TXT"; }
error()  { echo -e "${RED}[ERROR] $1${NC}" >&2; exit 1; }

# Root check
(( EUID == 0 )) || error "This script must be run as root (sudo)"

log "Starting workstation scan – reports will be in $BASE"

# Initialize reports
cat > "$REPORT_TXT" <<EOF
Ubuntu Workstation Scan Report
Generated: $(date)
Hostname:  $(hostname)
============================================================

EOF

cat > "$REPORT_HTML" <<EOF
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Workstation Scan Report</title>
<style>
  body {font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.6;}
  h1, h2 {color: #2c3e50;}
  h2 {border-bottom: 2px solid #eee; padding-bottom: 0.5rem;}
  table {border-collapse: collapse; width: 100%; margin: 1rem 0;}
  th, td {border: 1px solid #ddd; padding: 0.8rem; text-align: left;}
  th {background: #f4f6f6;}
  pre {background: #f8f9fa; padding: 1rem; overflow-x: auto; border-radius: 6px;}
  .warn {color: #e74c3c; font-weight: bold;}
</style></head><body>
<h1>Ubuntu Workstation Scan Report</h1>
<p>Generated: $(date) | Host: $(hostname)</p><hr>
EOF

# Start valid JSON
echo '{"scan_time": "'"$(date)"'", "hostname": "'"$(hostname)"'", "results": []}' > "$REPORT_JSON"

# Helper: append to JSON results array safely
json_append() {
    local obj="$1"
    jq ".results += [$obj]" "$REPORT_JSON" > "${REPORT_JSON}.tmp" && mv "${REPORT_JSON}.tmp" "$REPORT_JSON"
}

# Install missing tools quietly
log "Ensuring required tools are installed..."
for pkg in lynis clamav clamav-daemon lm-sensors smartmontools sysstat net-tools jq ufw; do
    dpkg -s "$pkg" &>/dev/null || {
        log "Installing $pkg..."
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -yqq "$pkg" || warn "Failed to install $pkg"
    }
done
[ -f /var/lib/clamav/main.cvd ] || { freshclam --quiet || warn "ClamAV update failed"; }

# 1. System Information
log "1/11 System information"
{
    echo "System Information"
    echo "------------------"
    lsb_release -a 2>/dev/null | grep Description || echo "Description: Unknown"
    uname -r | sed 's/^/Kernel:   /'
    hostname | sed 's/^/Hostname: /'
    uptime -p | sed 's/^/Uptime:   /'
    who -b | awk '{print "Last boot:",$3,$4}'
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>System Information</h2><table>"
    echo "<tr><td>OS</td><td>$(lsb_release -ds 2>/dev/null || echo Unknown)</td></tr>"
    echo "<tr><td>Kernel</td><td>$(uname -r)</td></tr>"
    echo "<tr><td>Hostname</td><td>$(hostname)</td></tr>"
    echo "<tr><td>Uptime</td><td>$(uptime -p)</td></tr>"
    echo "</table>"
} >> "$REPORT_HTML"

json_append '{"section": "System Info", "os": "'"$(lsb_release -ds 2>/dev/null || echo Unknown)"'", "kernel": "'"$(uname -r)"'"}'

# 2. Package Updates
log "2/11 Package updates"
apt-get update -qq
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c '/')
if (( UPGRADABLE > 0 )); then
    warn "$UPGRADABLE packages can be upgraded"
    echo "Upgradable packages: $UPGRADABLE – run 'apt upgrade'" >> "$REPORT_TXT"
else
    echo "All packages up to date" >> "$REPORT_TXT"
fi

{
    echo "<h2>Package Updates</h2>"
    (( UPGRADABLE > 0 )) && echo "<p class='warn'>$UPGRADABLE packages need upgrade</p>" || echo "<p>All packages up to date</p>"
} >> "$REPORT_HTML"
json_append '{"section": "Packages", "upgradable": '"$UPGRADABLE"'}'

# 3. Disk Usage & SMART
log "3/11 Disk usage & health"
HIGH_USAGE=$(df -h | awk 'NR>1 && int($5)>90 {print $5" on "$6}' | wc -l)
(( HIGH_USAGE > 0 )) && warn "High disk usage on $HIGH_USAGE partition(s)"
{
    echo "Disk Usage & Health"
    echo "-------------------"
    df -hT
    echo
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n[1-9]; do
        [[ -b "$disk" ]] || continue
        echo "SMART health for $disk:"
        smartctl -H "$disk" | grep -i result || echo "  SMART not supported"
    done
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>Disk Usage</h2><pre>$(df -hT)</pre>"
    (( HIGH_USAGE > 0 )) && echo "<p class='warn'>$HIGH_USAGE partition(s) >90% full</p>"
} >> "$REPORT_HTML"
json_append '{"section": "Disk", "high_usage_partitions": '"$HIGH_USAGE"'}'

# 4. Memory & Processes
log "4/11 Memory & processes"
USED_PCT=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')
(( USED_PCT > 90 )) && warn "Memory usage high: ${USED_PCT}%"
ZOMBIES=$(ps aux | awk '{if ($8=="Z") print}' | wc -l)
(( ZOMBIES > 0 )) && warn "$ZOMBIES zombie processes found"

{
    echo "Memory & Processes"
    echo "------------------"
    free -h
    echo "Memory usage: ${USED_PCT}%"
    echo "Top CPU processes:"
    ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -6
    echo "Zombie processes: $ZOMBIES"
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>Memory & Processes</h2><pre>$(free -h)\n\nTop CPU:\n$(ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | head -10)</pre>"
    (( USED_PCT > 90 )) && echo "<p class='warn'>Memory usage: ${USED_PCT}%</p>"
} >> "$REPORT_HTML"
json_append '{"section": "Memory", "usage_percent": '"$USED_PCT"', "zombies": '"$ZOMBIES"'}'

# 5. CPU Load & Temp
log "5/11 CPU load & temperature"
LOAD1=$(cut -d' ' -f1 /proc/loadavg)
if awk "BEGIN {exit !($LOAD1 > $(nproc) * 1.5)}"; then warn "High CPU load: $LOAD1"; fi

{
    echo "CPU Load & Temperature"
    echo "----------------------"
    uptime | grep -o 'load average:.*'
    sensors 2>/dev/null | grep -i 'core\|temp' || echo "No temperature sensors detected"
    echo
} >> "$REPORT_TXT"

{
    echo "<19><h2>CPU Load</h2><pre>$(uptime | grep -o 'load average:.*')</pre>"
    sensors &>/dev/null && echo "<pre>$(sensors | grep -A3 -i core)</pre>"
} >> "$REPORT_HTML"

# 6. Failed Systemd Units
log "6/11 Systemd failed units"
FAILED=$(systemctl --failed --no-legend | wc -l)
(( FAILED > 0 )) && warn "$FAILED systemd unit(s) failed"

{
    echo "Systemd Failed Units: $FAILED"
    systemctl --failed --no-legend || true
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>Systemd Status</h2>"
    (( FAILED > 0 )) && echo "<p class='warn'>$FAILED failed units</p><pre>$(systemctl --failed)</pre>" || echo "<p>All units active</p>"
} >> "$REPORT_HTML"
json_append '{"section": "Systemd", "failed_units": '"$FAILED"'}'

# 7. Security Quick Checks
log "7/11 Security checks (Lynis + ClamAV + UFW)"
LYNIS_OUT=$(mktemp); TEMP_FILES+=("$LYNIS_OUT")
lynis audit system --quick --quiet > "$LYNIS_OUT"
WARNINGS=$(grep -c -E "warning|suggestion" "$LYNIS_OUT" || echo 0)
(( WARNINGS > 20 )) && warn "Lynis found $WARNINGS suggestions/warnings"

CLAM_OUT=$(mktemp); TEMP_FILES+=("$CLAM_OUT")
clamscan -r /home --infected --quiet > "$CLAM_OUT" 2>&1 || true
INFECTED=$(grep -c "Infected files" "$CLAM_OUT" && awk '/Infected files/ {if ($NF>0) print $NF; else print 0}' || echo 0)
(( INFECTED > 0 )) && warn "ClamAV found $INFECTED infected file(s)"

UFW_STATUS=$(ufw status verbose | grep -q "Status: active" && echo "active" || echo "inactive/not installed")

{
    echo "Security Overview"
    echo "-----------------"
    echo "Lynis warnings/suggestions: $WARNINGS"
    echo "ClamAV infected files: $INFECTED"
    echo "UFW firewall: $UFW_STATUS"
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>Security Checks</h2>"
    echo "<table><tr><td>Lynis issues</td><td>$WARNINGS</td></tr>"
    echo "<tr><td>ClamAV infected</td><td>$INFECTED</td></tr>"
    echo "<tr><td>UFW</td><td>$UFW_STATUS</td></tr></table>"
} >> "$REPORT_HTML"
json_append '{"section": "Security", "lynis_issues": '"$WARNINGS"', "infected_files": '"$INFECTED"', "ufw": "'"$UFW_STATUS"'"}'

# 8. Network
log "8/11 Network diagnostics"
DNS_OK=$(nslookup ubuntu.com &>/dev/null && echo yes || echo no)
PING_OK=$(ping -c 3 -W 5 8.8.8.8 &>/dev/null && echo yes || echo no)

{
    echo "Network Status"
    echo "--------------"
    ip -brief addr show
    echo "Open ports (ss):"
    ss -tuln
    echo "DNS resolution: $DNS_OK"
    echo "Internet reachability: $PING_OK"
    echo
} >> "$REPORT_TXT"

{
    echo "<h2>Network</h2><pre>$(ip -brief addr)\n\n$(ss -tuln)</pre>"
    [[ $DNS_OK == no ]] && echo "<p class='warn'>DNS resolution failed</p>"
    [[ $PING_OK == no ]] && echo "<p class='warn'>No internet connectivity</p>"
} >> "$REPORT_HTML"

# Finalize reports
log "Finalizing reports..."

echo "Scan completed at $(date)" >> "$REPORT_TXT"
echo "<hr><p>Scan completed at $(date)</p></body></html>" >> "$REPORT_HTML"
jq . "$REPORT_JSON" > "${REPORT_JSON}.pretty" && mv "${REPORT_JSON}.pretty" "$REPORT_JSON"

log "Scan finished!"
echo
echo "Reports generated:"
echo "   Text : $REPORT_TXT"
echo "   HTML : $REPORT_HTML"
echo "   JSON : $REPORT_JSON"
echo
(( $(grep -c "WARNING" "$REPORT_TXT" || echo 0) > 0 )) && {
    echo "Warnings found:"
    grep "^WARNING:" "$REPORT_TXT" | sed 's/^WARNING: / - /'
} || echo "No warnings detected – system looks healthy!"

exit 0
