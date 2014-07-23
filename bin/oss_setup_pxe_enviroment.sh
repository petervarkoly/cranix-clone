#!/bin/bash

. /etc/sysconfig/language
. /etc/sysconfig/schoolserver

PASS=`/usr/sbin/oss_get_admin_pw`
SHA1PASS=`/usr/share/oss/tools/sha1pass.pl $PASS`
DATE=`/usr/share/oss/tools/oss_date.sh`
LANG=${RC_LANG:3:2}
SCHOOLNAME=`echo "uid admin attributes o" | oss_get_user.pl text | grep '^o ' | sed 's/o //'`

ADMINPASSWORD=`oss_ldapsearch uid=admin sambaNTPassword | grep sambaNTPassword: | sed 's/sambaNTPassword: //'`
INSTALLEDLANGUAGE=$INSTALLED_LANGUAGES
SCHOOLLANGUAGE=$(echo $INSTALLEDLANGUAGE|sed 's/_/-/g')
SCHOOLLANGUAGE=$(echo $SCHOOLLANGUAGE|sed 's/,/ /g')
array=($SCHOOLLANGUAGE)
len=${#array[*]}
i=0
while [ $i -lt $len ]; do
	KKK=$(echo ${array[$i]}|grep $SCHOOL_LANGUAGE)
	if [ $KKK ]; then
		SCHOOLLANGUAGE=$KKK
	fi
	let i++
done

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
   sed -i "s#SHA1PASS#$SHA1PASS#"      $base
done

for i in /srv/itool/config/*.templ
do
   base="/srv/itool/config/"`basename $i .templ`
   if [ ! -e $base ] 
   then
       cp $i $base
       sed -i "s/SCHOOLNAME/$SCHOOL_NAME/" $base
       sed -i "s/SCHOOLLANGUAGE/$SCHOOL_LANGUAGE/" $base
       sed -i "s/ntAdministratorPassword/$ADMINPASSWORD/" $base
   fi
done
