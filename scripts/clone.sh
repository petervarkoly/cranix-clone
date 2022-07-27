#!/bin/bash
###############################################################################
# Script:       clone.sh
# Copyright (c) Peter Varkoly, Nuremberg, Germany.
# All rights reserved.
#
# Authos:               Peter Varkoly
#
# Description:          Cloning tool for cloning more partitions
#
#
###############################################################################

curl ftp://${SERVER}/itool/scripts/clone-functions.sh > /root/clone-functions.sh
source /root/clone-functions.sh &> /dev/null || {
        echo "ERROR SERVER IS NOT AVAILABLE"
        echo "Fehler Server nicht erreichbar"
        sleep 10
        exit 1
}

## Set some variables
if [ -z "$SLEEP" ]; then
        SLEEP=1
fi

. /tmp/credentials
. /tmp/apiparams

# Since 4.4 admin and file server can be separated.
# The FILESERVER can be given as boot parameter
if [ -z "${FILESERVER}" ]; then
	FILESERVER=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/system/configuration/FILESERVER_NETBIOSNAME" )
	if [ -z  "${FILESERVER}" ]; then
		FILESERVER=${SERVER}
	fi
fi
mount -t cifs -o credentials=/tmp/credentials //${FILESERVER}/itool /mnt/itool

echo "HOSTNAME ${HOSTNAME}"
# Get my conf value if not defined by the kernel parameter
if  [ -z "$HW" ]; then
    HW=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/hwconf" )
    export HW
fi

echo "HW $HW"

if [ -z "$HW" ]; then
        dialog --colors  --backtitle "${CTOOLNAME} ${HOSTNAME}" \
                --title "\Zb\Z1Ein Fehler ist aufgetreten:" \
                --msgbox "Diesr Rechner hat keine Rechnerkonfiguration.\nBitte Rechnerkonfiguration setzten und\nRechner erneut in CloneTool starten.\n\nSo kann der Rechner nur manuell kann geklont werden." 17 60
else
        #Get my configuration description
        HWDESC=$(curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/description")
        echo "HWDESC $HWDESC"
	export HWDESC
        #Get my configuration type
        HWDEVTYPE=$(curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/deviceType")
        echo "HWDEVTYPE $HWDEVTYPE"
	export HWDEVTYPE
	if [ "$HWDEVTYPE" == "cloneProxy" ]; then
		get_real_config
	fi
fi
sleep $SLEEP
## Get the list of the harddisks
rm -rf /tmp/devs
mkdir -p /tmp/devs
HDs=$( gawk '{if ( $2==0 ) { print $4 }}' /proc/partitions | grep -v loop. | grep -v sr0 )
export HDs

## Get the DOMAIN
DOMAIN=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/domainName" )
echo "DOMAIN $DOMAIN"
export DOMAIN

## Analysing partitions
rm -rf /tmp/parts
for i in $HDs
do
   parted -m -s /dev/$i print > /tmp/prts
   j=1
   for p in $( ls /dev/$i[p0-9]* )
   do
     PART=$( echo $p | sed s#/dev/## )
     mkdir -p /tmp/parts/$PART
     echo "/^$j/ { printf(\"%s\",\$4) }" > /tmp/prts.awk
     gawk -F : -f /tmp/prts.awk /tmp/prts > /tmp/parts/$PART/size
     echo "/^$j/ { printf(\"%s\",\$5) }" > /tmp/prts.awk
     gawk -F : -f /tmp/prts.awk /tmp/prts > /tmp/parts/$PART/fs
     echo "/^$j/ { printf(\"%s\",\$6) }" > /tmp/prts.awk
     gawk -F : -f /tmp/prts.awk /tmp/prts > /tmp/parts/$PART/desc
     j=$((j+1))
   done
done

echo "SLEEP $SLEEP"
sleep $SLEEP

# Is hostname defined we save the hardware configuration
if [ "${HOSTNAME}" ]; then
    save_hw_info
fi

if [ "$MODUS" = "AUTO" ]; then
    # we only have to repair the MBR
    if [ "$PARTITIONS" = "MBR" ]; then
        mbr
        restart
    fi
    if [ "${PARTITIONS,,}" = "clean" ]; then
        clean_disks
        restart
    fi
    if [ "$PARTITIONS" = "all" ]; then
       PARTITIONS=$(curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/partitions")
       for i in $PARTITIONS
       do
           echo $i >> /tmp/partitions
       done
    else
       IFS=","
       for i in $PARTITIONS
       do
           [ "$i" = "MBR" ] && continue
           echo $i >> /tmp/partitions
       done
       unset IFS
    fi
    initialize_disks
    restore_partitions
    restart
fi

# Get Username and Password
USERNAME=`cat /tmp/username`
## Get the BINDDN

###############################
## Start the main dialog
###############################
while :
do

	if [ -z "$HW" ]; then
		dialog  --colors --help-button --backtitle "${CTOOLNAME} ${HWDESC} ${HOSTNAME}" \
			--nocancel --title "\Zb\Z1Hauptmenu" \
			--menu "Waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Clean"      "Alle Daten auf der Festplatte löschen" \
			"Bash"       "Starte root-Shell (nur fuer Experten)"\
			"Quit"       "Beenden"\
			"About"      "About" 2> /tmp/clone.input
	else
		dialog  --colors --help-button --backtitle "${CTOOLNAME} ${HWDESC} ${HOSTNAME}" \
			--nocancel --title "\Zb\Z1Hauptmenu" \
			--menu "Waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Restore"    "Rechner wiederherstellen" \
			"Partition"  "Bestimmte Partitionen wiederherstellen" \
			"Clone"      "Rechner klonen" \
			"MBR"        "Master Boot Record wiederherstellen" \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Clean"      "Alle Daten auf der Festplatte löschen" \
			"Bash"       "Starte root-Shell (nur fuer Experten)"\
			"Quit"       "Beenden"\
			"About"      "About" 2> /tmp/clone.input
	fi
        MODUS=$(cat /tmp/clone.input)

        ## Test if Help  ##
        if [ "${MODUS}" != "${MODUS/HELP/}" ]; then
                helpme ${MODUS/HELP/}
                continue
        fi

        case $MODUS in
		Restore)
			get_cloned_partitions
			initialize_disks
			restore_partitions
			restart
		;;
		Partition)
			select_partitions_to_restore
			restore_partitions
			restart
		;;
		Clone)
			## Menu Item Clone ##
			select_partitions || continue
			get_info          || continue
			clone
		;;
		MBR)
			## Menu Item MBR ##
			mbr
		;;
		Manual)
			## Menu Item Manual ##
			man_part
		;;
		Clean)
                        ## Menu Item Clean ##
                        clean_disks
                ;;
		Bash)
			## Menu Item Bash ##
			/bin/bash
		;;
		Quit)
			## Menu Item Quit ##
			dialog --colors  --backtitle "${CTOOLNAME} ${HWDESC} ${HOSTNAME}" \
				--title     "\Zb\Z1Beenden" \
				--ok-label  "Neu starten" \
				--cancel-label "Abbrechen" \
				--menu      "\nMoechten Sie das Clone Tool wirklich verlassen?\n\n\n " 15 60 1\
				            "" "> Aktuell verbunden mit ${SERVER} <"

			case $? in
			0)
				restart
			;;
			*)
			esac
		;;
		About)
			## Menu Item About ##
			dialog --colors  --backtitle "${CTOOLNAME} ${HWDESC} ${HOSTNAME}" \
				--title "\Zb\Z1About" \
				--msgbox "${ABOUT}\n Hostname : ${HOSTNAME}\n Festplatte(n): $HDs\n MAC-Adresse: ${MAC}" 17 60
		;;
	esac

done
