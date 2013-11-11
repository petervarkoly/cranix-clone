:answer0 echo " 0 "
ping admin > NULL

if %errorlevel% NEQ 0 goto answer0

netdom join HOSTNAME /Domain:WORKGROUP /UserD:register /PasswordD:register /ReBoot:2
del C:\script\domainjoin.bat
ping -n 10 admin > NULL
