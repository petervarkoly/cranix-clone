:answer0 echo " 0 "
ping admin > NULL
if %errorlevel% NEQ 0 goto answer0

if not exist c:\script\newCMID (
     echo "1" > c:\script\newCMID
     cscript c:\windows\system32\slmgr.vbs -rearm
     shutdown.exe /r /t 10 /f
     exit
     )

powershell -noprofile -executionpolicy bypass -file %systemdrive%\script\domainjoin.ps1

ping -n 10 admin > NULL
