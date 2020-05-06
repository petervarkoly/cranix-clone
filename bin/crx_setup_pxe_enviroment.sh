#!/bin/bash

. /etc/sysconfig/language
. /etc/sysconfig/cranix

DATE=`/usr/share/oss/tools/oss_date.sh`
LANG=${RC_LANG:3:2}

if [ -e /srv/tftp/linuxrc.config_$LANG ]
then
  cp  /srv/tftp/linuxrc.config_$LANG  /srv/tftp/linuxrc.config
else
  cp  /srv/tftp/linuxrc.config_DEFAULT  /srv/tftp/linuxrc.config
fi

for i in /srv/tftp/pxelinux.cfg/*.in
do
   base="/srv/tftp/pxelinux.cfg/"`basename $i .in`
   if [ -e $base ] 
   then
     cp $base $base.$DATE
   fi
   cp $i $base
done

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

