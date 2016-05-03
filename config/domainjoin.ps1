$newName  = "HOSTNAME".ToLower()  # HOST_NAME  --> edv-pc00
$domain   = "WORKGROUP".ToLower() # WORK_GROUP --> DomainName
$user     = "register"
$username = "$domain\$user" 
$currentName     = $(Get-WmiObject Win32_Computersystem).name.ToLower()
$currentDomain   = $(Get-WmiObject Win32_Computersystem).domain.ToLower()
$winVersionMajor = $([System.Environment]::OSVersion.Version.Major)
$winVersionMinor = $([System.Environment]::OSVersion.Version.Minor)
$password   = ConvertTo-SecureString –String "$user" –AsPlainText -Force
$credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $username, $password
$scriptsDir = "$env:SystemDrive\script"
$logFile    = "$env:SystemDrive\Windows\System32\domain_join_log_$(get-date -uformat '%Y-%m-%d_%H-%M').log"

Write-Output "Global variables:" | Out-File $logFile -Append
Write-Output "newName  = $newName" | Out-File $logFile -Append
Write-Output "domain   = $domain" | Out-File $logFile -Append
Write-Output "user     = $user" | Out-File $logFile -Append
Write-Output "username = $username" | Out-File $logFile -Append
Write-Output "currentName     = $currentName" | Out-File $logFile -Append
Write-Output "currentDomain   = $currentDomain" | Out-File $logFile -Append
Write-Output "winVersionMajor = $winVersionMajor" | Out-File $logFile -Append
Write-Output "winVersionMinor = $winVersionMinor" | Out-File $logFile -Append
Write-Output "scriptsDir = $scriptsDir" | Out-File $logFile -Append
Write-Output "logFile    = $logFile" | Out-File $logFile -Append

##################################### FUNCTIONS #####################################

function My-Rename-Computer
{
    param ( [Parameter(Mandatory=$true)][string]$name )
    process
    {
        try
        {
            $computer = Get-WmiObject -Class Win32_ComputerSystem
            $result = $computer.Rename($name)
            switch($result.ReturnValue)
            {       
                0
                {
                    return $true
                }
                5 
                {
                    Write-Output "You need administrative rights to execute this cmdlet" | Out-File $logFile -Append
                    return $false
                }
                default 
                {
                    Write-Output "Error - return value of " $result.ReturnValue | Out-File $logFile -Append
                    return $false
                }
            }
        }
        catch
        {
            Write-Output "Exception occurred in My-Rename-Computer " $Error | Out-File $logFile -Append
            return $false
        }
    }
}


##################################### MAIN #####################################

if( ("$winVersionMajor.$winVersionMinor" -eq "10.0") -or 
    ("$winVersionMajor.$winVersionMinor" -eq "6.3") -or 
    ("$winVersionMajor.$winVersionMinor" -eq "6.2") )
{
    if( "$winVersionMajor.$winVersionMinor" -eq "10.0" )
    {
        Write-Output "Worksatation is Windows 10 - version is 10.0" | Out-File $logFile -Append
    }
    elseif( "$winVersionMajor.$winVersionMinor" -eq "6.3" )
    {
        Write-Output "Worksatation is Windows 8.1 - version is 6.3" | Out-File $logFile -Append
    }
    elseif( "$winVersionMajor.$winVersionMinor" -eq "6.2" )
    {        Write-Output "Worksatation is Windows 8 - version is 6.2" | Out-File $logFile -Append
    }

    if( ($currentName -ne $newName) -and ($currentDomain -eq  $domain) ){
        Write-Output "Add workstation to workgroup!" | Out-File $logFile -Append
        Remove-Computer -Credential $credential -Force -Restart
    }elseif( $currentName -ne $newName ){
        Write-Output "Rename Workstation!" | Out-File $logFile -Append
        Rename-Computer -NewName $newName -Force -Restart
    }elseif( ($currentName -eq $newName) -and ($currentDomain -ne  $domain) -and ((gwmi win32_computersystem).partofdomain -ne $true) ){
        $objReturn = Add-Computer -DomainName $domain -Credential $credential -PassThru
        Write-Output "objReturn:" $objReturn.hasSucceeded | Out-File $logFile -Append
        if( $objReturn.hasSucceeded )
        {
            Write-Output "Successfully added workstation to domain!" | Out-File $logFile -Append
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        }else{
            Write-Output "Unsuccessfully added workstation to domain!" | Out-File $logFile -Append
        }
#        Write-Output "Add workstation to domain!" | Out-File $logFile -Append
#        Add-Computer -DomainName $domain -Credential $credential -Force -Restart
    }elseif( ($currentName -eq $newName) -and ($currentDomain -eq  $domain) -and ((gwmi win32_computersystem).partofdomain -eq $true) ){
        Write-Output "Workstation is domain joined!" | Out-File $logFile -Append
        if( Test-Path $scriptsDir ){
            Write-Output "Remove $scriptsDir directory!" | Out-File $logFile -Append
            Remove-Item -Path $scriptsDir -Force -Recurse
        }
    }
}
elseif( ("$winVersionMajor.$winVersionMinor" -eq "6.1") -or
        ("$winVersionMajor.$winVersionMinor" -eq "6.0") )
{
    if( "$winVersionMajor.$winVersionMinor" -eq "6.1" )
    {
        Write-Output "Worksatation is Windows 7 - version is 6.1" | Out-File $logFile -Append
    }
    elseif( "$winVersionMajor.$winVersionMinor" -eq "6.0" )
    {
        Write-Output "Worksatation is Windows Vista - version is 6.0" | Out-File $logFile -Append
    }    
    if( ($currentName -ne $newName) -and ($currentDomain -eq  $domain) ){
        Write-Output "Add workstation to workgroup!" | Out-File $logFile -Append
        $objReturn = Add-Computer -workgroupname "workgroup" -PassThru
        Write-Output "objReturn:" $objReturn | Out-File $logFile -Append
        if( $objReturn -Or $objReturn.hasSucceeded )
        {
            Write-Output "Successfully added workstation to workgroup!" | Out-File $logFile -Append
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        }else{
            Write-Output "Unsuccessfully added workstation to workgroup!" | Out-File $logFile -Append
        }
    }elseif( $currentName -ne $newName ){
        Write-Output "Rename Workstation!" | Out-File $logFile -Append
        $objReturn = My-Rename-Computer $newName
        Write-Output "objReturn:" $objReturn | Out-File $logFile -Append
        if( $objReturn )
        {
            Write-Output "Successfully renamed workstation!" | Out-File $logFile -Append
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        }else{
            Write-Output "Unsuccessfully renamed workstation!" | Out-File $logFile -Append
        }
    }elseif( ($currentName -eq $newName) -and ($currentDomain -ne  $domain) -and ((gwmi win32_computersystem).partofdomain -ne $true) ){
        Write-Output "Add workstation to domain!" | Out-File $logFile -Append
        $objReturn = Add-Computer -DomainName $domain -Credential $credential -PassThru
        Write-Output "objReturn:" $objReturn.hasSucceeded | Out-File $logFile -Append
        if( $objReturn.hasSucceeded )
        {
            Write-Output "Successfully added workstation to domain!" | Out-File $logFile -Append
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        }else{
            Write-Output "Unsuccessfully added workstation to domain!" | Out-File $logFile -Append
        }
    }elseif( ($currentName -eq $newName) -and ($currentDomain -eq  $domain) -and ((gwmi win32_computersystem).partofdomain -eq $true) ){
        Write-Output "Workstation is domain joined!" | Out-File $logFile -Append
        if( Test-Path $scriptsDir ){
            Write-Output "Remove $scriptsDir directory!" | Out-File $logFile -Append
            Remove-Item -Path $scriptsDir -Force -Recurse
        }
    }}
elseif( "$winVersionMajor.$winVersionMinor" -eq "5.1" )
{    Write-Output "Worksatation is Windows Xp - version is 5.1" | Out-File $logFile -Append}
