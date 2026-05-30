# Unrestrict AutoLogger directory
# $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
# icacls $autoLoggerDir /grant:r SYSTEM:`(OI`)`(CI`)F | Out-Null
 
# Stop and disable Diagnostics Tracking Service
Write-Host "Stopping and disabling Diagnostics Tracking Service..."
Stop-Service "DiagTrack"
Set-Service "DiagTrack" -StartupType Disabled
 
# Enable and start Diagnostics Tracking Service
# Set-Service "DiagTrack" -StartupType Automatic
# Start-Service "DiagTrack"
 
# Stop and disable WAP Push Service
Write-Host "Stopping and disabling WAP Push Service..."
Stop-Service "dmwappushservice"
Set-Service "dmwappushservice" -StartupType Disabled
 
# Enable and start WAP Push Service
# Set-Service "dmwappushservice" -StartupType Automatic
# Start-Service "dmwappushservice"
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "DelayedAutoStart" -Type DWord -Value 1

###################################################################################################
# Cranix modification
###################################################################################################

# Activate Administrator
net user administrator Cran1x0nl4 /active:yes >> "C:\admin_setup.log"

# Disable Hibernate 
# Disable sleep mode

powercfg -h off 

powercfg -x -standby-timeout-dc 0

powercfg -x -standby-timeout-ac 0

# Administrator needs this 

Set-ItemProperty -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLinkedConnections " -Type DWORD  -Value 1 

# Administrator stays forever

Set-LocalUser -Name "Administrator" -AccountNeverExpires >> "C:\admin_never.log"

Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters -Name Type -Value NTP >> "C:\time.log"

Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters -Name NtpServer -Value admin >> "C:\time2.log"

net time \\admin /SET /Y

### set WLAN

netsh wlan add profile filename="C:\config\WLAN-Funknetz.xml" user=all

$key = wmic path softwarelicensingservice get OA3xOriginalProductKey


write-host $key[2].TrimEND()

cscript $env:windir\system32\slmgr.vbs /upk
cscript $env:windir\system32\slmgr.vbs /cpky

changepk.exe /ProductKey $key[2].TrimEND()

cscript $env:windir\system32\slmgr.vbs /ato >> C:\salt\var\log\OEM_inst.log

