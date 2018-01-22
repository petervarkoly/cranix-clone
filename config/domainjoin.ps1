param (
    [Parameter(Mandatory=$true)][string]$mode
)

$newName  = "HOSTNAME".ToLower()  # HOSTNAME  --> edv-pc00
$domain   = "DOMAIN".ToLower() # DOMAIN --> DomainName
$user     = "register"
$username = "$domain\$user" 
$currentName     = $(Get-WmiObject Win32_Computersystem).name.ToLower()
$currentDomain   = $(Get-WmiObject Win32_Computersystem).domain.ToLower()
$winVersionMajor = $([System.Environment]::OSVersion.Version.Major)
$winVersionMinor = $([System.Environment]::OSVersion.Version.Minor)
$scriptsDir = "$env:SystemDrive\script"
$logFile    = "$env:SystemDrive\Windows\System32\domain_join_log_$(get-date -uformat '%Y-%m-%d_%H-%M').log"
$password   = $user | ConvertTo-SecureString -asPlainText -Force
if( "$winVersionMajor.$winVersionMinor" -eq "10.0" ){
    $credential  = New-Object System.Management.Automation.PSCredential($user,$password)
}else{
    $credential  = New-Object System.Management.Automation.PSCredential($username,$password)
}
#$credential = New-Object TypeName System.Management.Automation.PSCredential ArgumentList $username, $password

##################################### FUNCTIONS #####################################

function Log
{
    param ( [Parameter(Mandatory=$true)][string]$message )
    Write-Output "$message" | Out-File $logFile -Append
}

function LogWinVersion
{
    param ( [Parameter(Mandatory=$true)][string]$winver )
    if( "$winver" -eq "10.0" )
    {
        Log ("Worksatation is Windows 10 - version is 10.0")
    }
    elseif( "$winver" -eq "6.3" )
    {
        Log ("Worksatation is Windows 8.1 - version is 6.3")
    }
    elseif( "$winver" -eq "6.2" )
    {
        Log ("Worksatation is Windows 8 - version is 6.2")
    }
    elseif( "$winver" -eq "6.1" )
    {
        Log ("Worksatation is Windows 7 - version is 6.1")
    }
    elseif( "$winver" -eq "6.0" )
    {
        Log ("Worksatation is Windows Vista - version is 6.0")
    }
    elseif( "$winver" -eq "5.1" )
    {
        Log ("Worksatation is Windows Xp - version is 5.1")
    }
    else
    {
        Log ("Worksatation is other OS and version")
    }
}

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
                    Log ("You need administrative rights to execute this cmd!")
                    return $false
                }
                default
                {
                    Log ("Error - return value of: " + $result.ReturnValue)
                    return $false
                }
            }
        }
        catch
        {
            Log ("Exception occurred in My-Rename-Computer!")
            Log ("Exception.Message: " + $_.Exception.Message)
            return $false
        }
    }
}

function RemoveWsFromDomain
{
    if( ($currentName -ne $newName) -and ($currentDomain -eq  $domain) ){
        Log ("Add workstation to workgroup!")
        if(     ("$winVersionMajor.$winVersionMinor" -eq "10.0") -or ("$winVersionMajor.$winVersionMinor" -eq "6.3") -or ("$winVersionMajor.$winVersionMinor" -eq "6.2") )
        {
            try
            {
                Add-Computer -workgroupname "workgroup" -PassThru
                Log ("Added workstation successfully to workgroup!")
                #Restart-Computer -Force
                Start-Sleep -Seconds 5
            }
            catch
            {
                Log ("Failed to add workstation to workgroup!")
                Log ("Exception.Message: " + $_.Exception.Message)
            }
        }
        elseif( ("$winVersionMajor.$winVersionMinor" -eq "6.1")  -or ("$winVersionMajor.$winVersionMinor" -eq "6.0") )
        {
            try
            {
                Add-Computer -workgroupname "workgroup" -PassThru
                Log ("Added workstation successfully to workgroup!")
                #Restart-Computer -Force
                Start-Sleep -Seconds 5
            }
            catch
            {
                Log ("Failed to add workstation to workgroup!")
                Log ("Exception.Message: " + $_.Exception.Message)
            }
        }
    }else{
        Log "Workstation is in workgroup!"
    }
}

function RenameWs
{
    if( $currentName -ne $newName ){
        Log ("Rename workstation from " + $currentName + " to " + $newName + "!")
        if(     ("$winVersionMajor.$winVersionMinor" -eq "10.0") -or ("$winVersionMajor.$winVersionMinor" -eq "6.3") -or ("$winVersionMajor.$winVersionMinor" -eq "6.2") )
        {
            try
            {
                Rename-Computer -NewName $newName -Force
                Log ("Renamed workstation successfully!")
                Restart-Computer -Force
                Start-Sleep -Seconds 5
                Exit
            }
            catch
            {
                Log ("Failed to rename workstation!")
                Log ("Exception.Message: $_.Exception.Message")
            }
        }
        elseif( ("$winVersionMajor.$winVersionMinor" -eq "6.1")  -or ("$winVersionMajor.$winVersionMinor" -eq "6.0") )
        {
            $objReturn = My-Rename-Computer $newName
            Log "objReturn: " + $objReturn
            if( $objReturn )
	        {
                Log ("Renamed workstation successfully!")
                Restart-Computer -Force
                Start-Sleep -Seconds 5
                Exit
            }else{
                Log ("Failed to rename workstation!")
            }
        }
    }else{
        Log ("Name is already " + $newName + "!")
    }
}

function AddWsToDomain
{
    if( ($currentName -eq $newName) -and ($currentDomain -ne $domain) -and ((gwmi win32_computersystem).partofdomain -ne $true) ){
        Log ("Adding workstation to domain " + $domain + "!")
        try
        {
            Add-Computer -DomainName $domain -Credential $credential #-PassThru
            Log ("Added Workstation successfully to domain " + $domain + "!")
            Restart-Computer -Force
            Start-Sleep -Seconds 5
        }
        catch
        {
            Log ("Failed to add workstation to domain " + $domain + "!")
            Log ("Exception.Message: " + $_.Exception.Message)
        }
    }else{
        Log ("Workstation ist already a member of " + $domain + "!")
    }
}

function RemoveScriptDir
{
    if( ( ("$mode" -eq "domainjoin") -and ($currentName -eq $newName) -and ($currentDomain -eq $domain) -and ((gwmi win32_computersystem).partofdomain -eq $true)) -or
        ( ("$mode" -eq "rename")     -and ($currentName -eq $newName) )
    ){
        if( Test-Path $scriptsDir ){
            Log ("Removing script directory!")
            Remove-Item -Path $scriptsDir -Force -Recurse
        }else{
            Log ("Script directory does not exist!")
        }
    }
}


##################################### MAIN #####################################

Log "Global variables:"
Log "mode     = $mode"
Log "newName  = $newName"
Log "domain   = $domain"
Log "user     = $user"
Log "username = $username"
Log "currentName     = $currentName"
Log "currentDomain   = $currentDomain"
Log "winVersionMajor = $winVersionMajor"
Log "winVersionMinor = $winVersionMinor"
Log "scriptsDir = $scriptsDir"
Log "logFile    = $logFile"
LogWinVersion "$winVersionMajor.$winVersionMinor"


if( "$mode" -eq "rename" ){
    RemoveWsFromDomain
    RenameWs
    RemoveScriptDir
}elseif( "$mode" -eq "domainjoin" ){
    RemoveWsFromDomain
    RenameWs
    AddWsToDomain
    RemoveScriptDir
}

