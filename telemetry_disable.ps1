# Requires Administrator privileges
# Disable telemetry settings in Windows 11

# 1. Disable telemetry via registry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "MaxTelemetryAllowed" -Value 0

# 2. Disable diagnostic data
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "Enabled" -Value 0

# 3. Disable Connected User Experiences and Telemetry service
Stop-Service -Name "DiagTrack" -Force
Set-Service -Name "DiagTrack" -StartupType Disabled

# 4. Disable telemetry-related scheduled tasks
$tasks = @(
    "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "Microsoft\Windows\Autochk\Proxy"
)
foreach ($task in $tasks) {
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
}

# 5. Disable advertising ID
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0

# 6. Disable settings sync
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync" -Name "SyncPolicy" -Value 5

# 7. Disable feedback notifications
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0

# 8. Disable telemetry in Windows Error Reporting
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1

# 9. Disable Cortana (optional, as it involves telemetry)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

# 10. Disable Windows Insider telemetry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" -Name "EnablePreviewBuilds" -Value 0

Write-Host "Telemetry settings have been disabled. Please restart your system for changes to take effect."
