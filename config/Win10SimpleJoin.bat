:answer0 echo " 0 "
ping admin > NULL

if %errorlevel% NEQ 0 goto answer0


#Rename Computer
(Get-WmiObject win32_computersystem).rename("HOSTNAME")

#Create Credential Object
$User  = "WORKGROUP\register"
$PWord = ConvertTo-SecureString –String "register" –AsPlainText -Force
$Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord
Add-Computer -DomainName WORKGROUP -Credential $Credential -Restart -Force

