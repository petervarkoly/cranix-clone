#!/bin/bash 
sysadmins_gn=$( crx_get_gidNumber.sh sysadmins )
chmod     755      /srv/itool
chgrp -R $sysadmins_gn /srv/itool
chmod    2755      /srv/itool/config
chmod    2775      /srv/itool/hwinfo
chmod -R 2775      /srv/itool/images
setfacl -m g:$sysadmins_gn:rwx  /srv/itool/images
chmod -R 755       /srv/itool/ROOT
/usr/sbin/crx_setup_pxe_enviroment.sh &> /dev/null
DATE=`date +%Y-%m-%d:%H-%M`
if [ -e /etc/xinetd.d/tftp ]
then
  cp /etc/xinetd.d/tftp /etc/xinetd.d/tftp.$DATE
fi
cp /etc/xinetd.d/tftp.in /etc/xinetd.d/tftp
if [ ! -e /usr/share/cranix/templates/pxeboot ]
then
    cp /usr/share/cranix/templates/pxeboot.in /usr/share/cranix/templates/pxeboot
fi
if [ ! -e /usr/share/cranix/templates/efiboot ]
then
    cp /usr/share/cranix/templates/efiboot.in /usr/share/cranix/templates/efiboot
fi
