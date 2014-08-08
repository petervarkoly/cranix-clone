:answer0 echo " 0 "
ping admin > NULL

if %errorlevel% NEQ 0 goto answer0

if not exist c:\script\newCMID (
     echo "1" > c:\script\newCMID
     cscript c:\windows\system32\slmgr.vbs -rearm
     shutdown.exe /r /t 10 /f
     exit
     )

if exist c:\script\renamed netdom join HOSTNAME /Domain:WORKGROUP /UserD:register /PasswordD:register /ReBoot:2
if exist c:\script\renamed del C:\script\domainjoin.bat

echo "1" > c:\script\renamed
netdom renamecomputer OLDNAME /newname:HOSTNAME /force /Reboot:5

