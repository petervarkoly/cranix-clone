#!/bin/bash
SERVER=install
mkdir /mnt/sda{1,2}
mount /dev/sda1 /mnt/sda1
mount /dev/sda2 /mnt/sda2
echo "username=ossreader" >  /tmp/credentials
echo "password=ossreader" >> /tmp/credentials
echo "ossreader" > /tmp/username
echo "ossreader" > /tmp/userpassword
chmod 400 /tmp/userpassword
chmod 400 /tmp/credentials
. /tmp/credentials
TOKEN=$( curl --insecure -X POST --header 'Content-Type: application/x-www-form-urlencoded' --header 'Accept: text/plain' -d "username=$username&password=$password" 'https://admin/api/sessions/login' )
HOSTNAME=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" 'https://admin/api/sessions/dnsName' )
DOMAIN=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" 'https://admin/api/sessions/domainName' )
echo "TOKEN=$TOKEN"       >  /tmp/apiparams
echo "HOSTNAME=$HOSTNAME" >> /tmp/apiparams
. /tmp/apiparams
sed -i "s/^id:.*/id: ${HOSTNAME}.${DOMAIN}/" /mnt/sda2/salt/conf/minion
rm -f /mnt/sda2/salt/conf/pki/minion/*
rm -r /mnt/sda2/scripts
rm -r /mnt/sda1/scripts
curl --insecure -X PUT --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" 'https://admin/api/clonetool/resetMinion'
grep id: /mnt/sda2/salt/conf/minion
umount /dev/sda1
umount /dev/sda2
ps aux | grep start

