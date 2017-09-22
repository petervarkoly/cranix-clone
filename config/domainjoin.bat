:answer0 echo " 0 "
ping admin > NULL
if %errorlevel% NEQ 0 goto answer0

powershell -noprofile -executionpolicy bypass -file %systemdrive%\script\domainjoin.ps1 -mode domainjoin

ping -n 10 admin > NULL

