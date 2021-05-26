#!/bin/bash 
sysadmins_gn=$( crx_get_gidNumber.sh sysadmins )
chmod     755      /srv/itool
chgrp -R $sysadmins_gn /srv/itool
chmod    2755      /srv/itool/config
chmod    2775      /srv/itool/hwinfo
chmod -R 2775      /srv/itool/images
setfacl -m g:$sysadmins_gn:rwx  /srv/itool/images
chmod -R 755       /srv/itool/ROOT

