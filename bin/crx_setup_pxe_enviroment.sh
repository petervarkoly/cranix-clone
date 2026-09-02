#!/bin/bash

VERSION=$1
. /etc/sysconfig/language
. /etc/sysconfig/cranix

DATE=$( /usr/share/cranix/tools/crx_date.sh )
LANG=${RC_LANG:3:2}

for i in /srv/itool/config/*.templ
do
   base="/srv/itool/config/"`basename $i .templ`
   if [ ! -e $base ] 
   then
       cp $i $base
       sed -i "s/SCHOOLNAME/$CRANIX_NAME/" $base
       sed -i "s/SCHOOLLANGUAGE/$CRANIX_LANGUAGE/" $base
   fi
done

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
if [ ! -e /srv/itool/config/WinDomain.xml ]
then
        cp /srv/itool/config/WinDomain.xml.templ /srv/itool/config/WinDomain.xml
fi

/usr/bin/wget http://downloads.cephalix.eu/boot/initrd -O /srv/tftp/boot/initrd
/usr/bin/wget http://downloads.cephalix.eu/boot/linux -O /srv/tftp/boot/linux
/usr/bin/wget http://downloads.cephalix.eu/boot/squashfs.img -O /srv/ftp/agama/squashfs.img

