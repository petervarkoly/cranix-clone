###############################################################################
# Script:       clone.sh
# Copyright (c) Peter Varkoly, Nuremberg, Germany.
# All rights reserved.
#
# Authos:               Peter Varkoly
#
# Description:          Cloning tool for cloning more partitions
#
                                IVERSION="@VERSION@"

                                IBUILD="@DATE@"
#
###############################################################################

ABOUT="CloneTool\n\n
Ein Werkzeug zum sichern und wiederherstellen von Computern.\n\n
Version: ${IVERSION}\n
Autor  : Dipl.-Ing. Peter Varkoly\n
Datum  : ${IBUILD}\n

";

milestone()
{
	if [ -z "$CDEBUG" ]; then
		return
	fi
	echo -n "Milestone $1";
	read
}

backup_image()
{
	dialog --colors --backtitle  "CloneTool - ${IVERSION} ${HWDESC}" \
		--title "\Zb\Z1Partition: $DESC" --nocancel \
	        --menu  "Backup des alten Images." 10 50 4 "Yes" "Vorhandenes Image speichern" "No" "Vorhandenes Image ueberschreiben" 2> /tmp/itool.input
	if [ $? -ne 0 ]; then
		return
	fi
	BACKUP=$(cat /tmp/itool.input)
	if [ $BACKUP = "Yes" ]; then
		backupname="$(ls --full-time /mnt/itool/images/$HW/$PARTITION.img | gawk '{print $6"-"$7}' | sed s/\.000000000// | sed s/:/-/g )-$PARTITION.img"
		mv /mnt/itool/images/$HW/$PARTITION.img /mnt/itool/images/$HW/$backupname
	        dialog --colors --backtitle  "CloneTool - ${IVERSION} ${HWDESC}" \
			--title "\Zb\Z1Partition: $DESC" --nocancel \
			--msgbox "Das vorhande Abbild wurde unter folgendem Pfad gespeichert:\n/mnt/itool/images/$HW/$backupname" 6 70
	fi
	milestone "End backup_image"
}
#########################
# The image save cmd
# saveimage $PARTITON /mnt/itool [ partclone|partimage|dd|dd_rescue ] [ cleanup ]
########################
saveimage ()
{
	local TOOL=$ITOOL
	#Clean up the partition if neccessary
        PART=${1##/dev/}
        if [ "${CLEANUP}_${PART}" = "1" ]; then
            echo "Clean Up $PART"
            mkdir -p /mnt/$PART
            mount /dev/$PART /mnt/$PART
            cont=$( df | gawk "/$PART / { print \$4-10 }" )
            count=$(( count/64 ))
            dd if=/dev/zero of=/mnt/$PART/null bs=65536 count=$count
            rm /mnt/$PART/null
            umount /mnt/$PART
        fi
	test -e $2 && rm -f $2
	if [ "$3" ]; then
		TOOL=$3
	fi
        case $TOOL in
                partclone)
			FSTYPE=$( cat /tmp/parts/$1/fs )
			partclone.$FSTYPE -c -s /dev/$1 -O $2
		;;
                partimage)
                        partimage -z1 -f3 -V0 -o -d --batch save /dev/$1 $2
                ;;
                dd)
			echo "#################################################"
			echo "#    Das erstellen des Images wurde gestartet.  #"
			echo "# Das kann sehr viel Zeit in Anschpruch nehmen. #"
			echo "#################################################"
                        dd if=$1 bs=65536 | gzip > $2
			sync
                ;;
                dd_rescue)
			echo "#################################################"
			echo "#    Das erstellen des Images wurde gestartet.  #"
			echo "# Das kann sehr viel Zeit in Anschpruch nehmen. #"
			echo "#################################################"
                        dd_rescue -y 0 -f -a /dev/$1 /dev/stdout | gzip > $2
			sync
                ;;
        esac
	echo $TOOL > $2.tool
	milestone "End saveimge $1,$2,$3,$TOOL"
}

#########################
# The image restore cmd
# restore $PARTITON /mnt/itool [ partclone|partimage|dd|dd_rescue ]
########################
restore ()
{
	local TOOL=$ITOOL
	if [ "$3" ]; then
		TOOL=$3
	elif [ -e $2.tool ]; then
		TOOL=$( cat $2.tool )
	fi
        case $TOOL in
                partclone)
			if [ "$MULTICAST" ]; then
				udp-receiver --nokbd 2> /dev/null | partclone.restore -O $1
			else
				partclone.restore -s $2 -O $1
			fi
		;;
                partimage)
			if [ "$MULTICAST" ]; then
				udp-receiver --nokbd 2> /dev/null | gunzip | partimage -f3 --batch restore $1 stdin
			else
				partimage -f3 --batch restore $1 $2
			fi
                ;;
                dd)
			if [ "$MULTICAST" ]; then
                       udp-receiver --nokbd 2> /dev/null | gunzip | dd of=$1 bs=65536
			else
				echo "#################################################"
				echo "# Das Zurückspielen des Images wurde gestartet. #"
				echo "# Das kann sehr viel Zeit in Anschpruch nehmen. #"
				echo "# Warten bis das Hauptmenü wieder kommt!  #"
				echo "#################################################"
                       cat $2 | gunzip | dd of=$1 bs=65536
			fi
                ;;
                dd_rescue)
			if [ "$MULTICAST" ]; then
				udp-receiver --nokbd 2> /dev/null | gunzip | /bin/dd_rescue /dev/stdin $1
			else
				cat $2 | gunzip | dd_rescue /dev/stdin $1
			fi
                ;;
        esac
	milestone "End restore $1,$2,$3,$TOOL"
}

#########################
# Some helper commands
#########################
cls ()
{
    echo -en "\033c"
}

restart()
{
	#umount /mnt/itool
	sleep 2
	exit 0
}

################################
# helpme  <What>
################################
helpme ()
{
        case $1 in
                Restore)
                        HELP="Alle Systemimage und die Daten-Partitionen werden wiederhergestellt bzw. neu formatiert.\n"
                ;;
                Partition)
                        HELP="Ausgewaehlte Systemimage und Daten-Partitionen werden wiederhergestellt bzw. neu formatiert.\n"
                ;;
                Clone)
                        HELP="Die Partitionierung und ausgewaehlte Partitionen des Clients werden auf den Server gespeichert.\n"
                ;;
                Manual)
                        HELP="Partimage wird gestartet und Sie koennen manuell beliebige Partitionen archivieren.\n"
                        HELP="${HELP}Den, fuer die Speicherung von Images, vorgesehenen Bereich auf dem Server findent Sie unter /mnt/itool/images/manual."
                ;;
                Partimage)
                        HELP="Partimage wird gestartet und Sie koennen manuell beliebige Partitionen archivieren.\n"
                        HELP="${HELP}Den, fuer die Speicherung von Images, vorgesehenen Bereich auf dem Server findent Sie unter /mnt/itool/images/manual."
                ;;
                *)
                        HELP="No help for this section";
                ;;
        esac
        dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC}" --title "\Zb\Z1Help for $1" --msgbox "${HELP}" 10 70
}

#####################################
# manual backup restore of partitions
#####################################
man_part()
{
   [ -e /tmp/disklist ]   && rm -f /tmp/disklist
   [ -e /tmp/partitions ] && rm -f /tmp/partitions
   for i in $( ls -d /tmp/parts/* )
   do
      fs=$( cat $i/fs )
      if [ -z "$fs" -o "${fs/linux-swap}" != "$fs" ]; then
         continue
      fi
      p=$( basename $i )
      echo -n "$p '$(cat $i/desc) $(cat $i/size) $(cat $i/fs)' " >> /tmp/partitions
   done
   echo -n 'dialog --colors --backtitle "CloneTool - '${IVERSION}'" --title "Manuelles Backup/Restore einer Partition" --menu  "Zur Verfuegung stehende Partitionen:" 20 50 8 ' > /tmp/command
   cat /tmp/partitions >> /tmp/command
   echo ' 2> /tmp/itool.input' >> /tmp/command
   . /tmp/command
   if [ $? -ne 0 ]; then
        return
   fi
   PARTITION=$(cat /tmp/itool.input)
   for HD in $HDs
   do
  if [  grep $HD /tmp/itool.input ]; then
		break;
	fi
   done

   dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup/Restore der Partition $PARTITION" \
          --menu "Waehlen Sie den gewuenschten modus" 20 50 4 "Backup" "Partition speichern" "Restore" "Partition wiederherstellen" 2> /tmp/itool.input
   if [ $? -ne 0 ]; then
        return
   fi
   MODE=$(cat /tmp/itool.input)

   if [ $MODE = "Backup" ]; then
        dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup der Partition $PARTITION" \
               --inputbox "Geben Sie einen Namen fuer das Image ein:\nDer Name darf nur folgende Zeichen erhalten a-Z1-9_." 10 60 2> /tmp/itool.input
        if [ $? -ne 0 ]; then
                return
        fi
        NAME=$( cat /tmp/itool.input | sed 's/[^a-zA-Z1-9_]//' )
        # make it sure the directory do exists
        mkdir -p /mnt/itool/images/manual/
	#Ask for backup mode
	dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup der Partition $PARTITION nach $NAME" \
		--nocancel --radiolist "Zu verwendende Imaging Tool waehlen!" 10 80 4 \
		partclone "Partclone: für fast alle Filesysteme" off \
		partimage "Partimage: für ext2 ext3 und ntfs" off \
		dd_rescue "Auch für fehlerhaften Partitionen geeignet" off \
		dd	  "dd"        off \
		2> /tmp/itool.input
	TOOL=$(cat /tmp/itool.input)
	#Ask for mbr
	dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup der Partition $PARTITION nach $NAME" \
		--nocancel --radiolist "Partitionierung speichern?" 10 80 4 \
		yes "Ja" on \
		no  "Nein" off \
		2> /tmp/itool.input
	MBR=$(cat /tmp/itool.input)
	if [ $MBR = "yes" ]; then
		dd of=/mnt/itool/images/manual/$NAME.parting if=/dev/$HD count=2048 bs=512 > /dev/null 2>&1
	fi
        saveimage $( baseaname $PARTITION ) /mnt/itool/images/manual/$NAME.img $TOOL
        chmod 775 /mnt/itool/images/manual/$NAME.img
        sleep $SLEEP
   else
        rm /tmp/manual
        touch /tmp/manual
        for i in /mnt/itool/images/manual/*img
        do
            n=`basename $i .img`
            test $n = '*img' && break
            echo -n "\"$n\" " >> /tmp/manual
            ls -lh --time-style=long-iso  $i | gawk 'NF==8 { printf("\"%s %s %s\" ",$6,$7,$5) }' >> /tmp/manual
        done

        SIZE=$(ls -l /tmp/manual | gawk '{ print $5 }')
        if [ $SIZE -eq 0 ]; then
            dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Warnung" --msgbox "Es sind keine manuell erstellten Images auf dem Server vorhanden!" 10 70
            return
        fi
        echo -n 'dialog --colors --backtitle "CloneTool - '${IVERSION}'" --title "Manuelles Backup/Restore einer Partition" --menu  "Zur Verfuegung stehende Images:" 20 70 8 ' > /tmp/command
        cat /tmp/manual >> /tmp/command
        echo ' 2> /tmp/itool.input' >> /tmp/command
        . /tmp/command
        if [ $? -ne 0 ]; then
                return
        fi
        NAME=$(cat /tmp/itool.input)
	if [ -e /mnt/itool/images/manual/$NAME.parting ]; then
		#Ask for mbr
		dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup der Partition $PARTITION nach $NAME" \
			--nocancel --radiolist "Partitionierung wiederherstellen?" 10 80 4 \
			yes "Ja" on \
			no  "Nein" off \
			2> /tmp/itool.input
		MBR=$(cat /tmp/itool.input)
		if [ $MBR = "yes" ]; then
			dd if=/mnt/itool/images/manual/$NAME.parting of=/dev/$HD count=2048 bs=512 > /dev/null 2>&1
		fi
	fi
        dialog --colors --backtitle "CloneTool - ${IVERSION}" --title "\Zb\Z1Manuelles Backup einer Partition" \
               --infobox "Partimage wird gestartet. Bitte warten!" 10 60
	restore $PARTITION /mnt/itool/images/manual/$NAME.img
   fi
}

select_partitions()
{
    # This funciton get the list of the avaiable partitions and starts an
    # checklist dialog to select the partitions to clone or to restore.
    # This will be saved into the file /tmp/partitions
    [ -e /tmp/disklist ]   && rm -f /tmp/disklist
    [ -e /tmp/partitions ] && rm -f /tmp/partitions
    for i in $( ls -d /tmp/parts/* )
    do
       fs=$( cat $i/fs )
       if [ -z "$fs" -o "${fs/linux-swap}" != "$fs" ]; then
          continue
       fi
       p=$( basename $i )
       desc=$( get_config $p DESC )
       if [ -z "$desc" ]; then
	   desc="$( cat $i/desc ) $( cat $i/size  ) $( cat $i/fs )"
       fi
       echo -n "$p \"$desc\" on " >> /tmp/partitions
    done
    echo -n "dialog --colors --backtitle \"CloneTool - ${IVERSION} ${HWDESC}\" --title \"Zur Verfuegung stehende Partitionen\" --checklist \"Waehlen Sie die zu bearbeitende Partitionen\" 18 60 8 " > /tmp/command
    cat /tmp/partitions >> /tmp/command
    echo ' 2> /tmp/partitions' >> /tmp/command
    . /tmp/command
    if [ $? -ne 0 ]; then
         return 1
    fi
    sed -i 's#"##g'     /tmp/partitions
    sleep $SLEEP
    milestone "End select_partitions"
    return 0
}

save_hw_info()
{
    if [ ! -e /mnt/itool/hwinfo/${HOSTNAME} ]; then
	mkdir -p /mnt/itool/hwinfo/${HOSTNAME}
	let i=100
        hw_items="bios cdrom chipcard cpu disk gfxcard keyboard memory monitor mouse netcard printer sound storage-ctrl"
        for hwitem in $hw_items
        do
	    echo $(($i/14)) | dialog --colors --sleep 1 --backtitle "CloneTool - ${IVERSION} ${HWDESC}" --title "\Zb\Z1Status" --gauge "Hardwarekonfiguration wird gespeichert: $hwitem"  10 60
            hwinfo --$hwitem > /mnt/itool/hwinfo/${HOSTNAME}/$hwitem
	    i=$((i+100))
        done
    fi
}

# Get the necessary configuration values from server
# get_config Partition Variable
get_config()
{
    curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/$1/$2"
}

# Add the necessary configuration values to server
# set_config Partition Variable "Value"
set_config()
{
    VALUE=$( echo $3 | sed 's/ /%20/g' )
    curl --insecure -X PUT --header 'Content-Type: application/json' --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/$1/$2/$VALUE"
}

get_info()
{
    # Get the description of the partitions
    echo -n "dialog --colors --backtitle \"CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}\" --title \"Beschreibung der Partitionen\" " >  /tmp/getdescriptions
    echo -n "--form \"Geben Sie eine kurze Beschreibung fuer die Partitionen\" 20 60 10 "		>> /tmp/getdescriptions
    let j=1
    for i in `cat /tmp/partitions`
    do
        desc=$( get_config $i DESC )
        if [ -z "$desc" ]; then
	   desc="$( cat /tmp/parts/$i/desc ) $( cat /tmp/parts/$i/size  )"
	fi
        echo -n "$i $j 1 \"$desc\" $j 10 40 40 " >> /tmp/getdescriptions
	j=$((j+1))
    done
    echo -n " 2> /tmp/descriptions" >> /tmp/getdescriptions
    . /tmp/getdescriptions
    if [ $? -ne 0 ]; then
         return 1
    fi

    sleep $SLEEP

    let i=1
    for PARTITION in `cat /tmp/partitions`
    do
        DESC=`gawk "NR==$i { print }" /tmp/descriptions`
	set_config $PARTITION DESC "$DESC"
	OS=$( get_config $PARTITION OS )
	WinBoot="off"; Win10="off"; Win7="off"; Win8="off"; Linux="off"; Data="off";
	case $OS in
	    WinBoot) WinBoot="on";;
	    Win10) Win10="on";;
	    Win7)  Win7="on";;
	    Win8)  Win8="on";;
	    Linux) Linux="on";;
	    Data) Data="on";;
	esac

        dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
		--title "\Zb\Z1Partition: $DESC" --nocancel \
		--radiolist "Waehlen Sie das Betriebsystem:" 18 60 8 \
		Win10    "Windows 10"           $Win10 \
		Win7     "Windows 7"            $Win7 \
		WinBoot  "Windows Bootpartition" $WinBoot \
		Win8     "Windows 8"            $Win8 \
		Linux    "Linux"                $Linux \
		Data     "Partition fuer Daten" $Data 2> /tmp/out
	OS=`cat /tmp/out`
	set_config $PARTITION OS $OS
        sleep $SLEEP

	case $OS in
	    WinBoot)
	        set_config $PARTITION JOIN "no"
		if [ -e /mnt/itool/images/$HW/$PARTITION.img ]; then
			backup_image /mnt/itool/images/$HW/$PARTITION.img
		fi
	    ;;
	    Win*)
		JOIN=$( get_config $PARTITION JOIN )
		Domain="off"; Workgroup="off"; No="off";
		case $JOIN in
		    Domain)     Domain="on";;
		    no)         No="on";;
		esac
		dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--title "\Zb\Z1Partition: $DESC" --nocancel \
			--radiolist "Windows Anmeldung:" 11 60 4 \
			Domain    "Windows Domainenmitglied"               $Domain \
			no	  "Keine Aufnahme"                         $No 2> /tmp/out
	        JOIN=`cat /tmp/out`
	        set_config $PARTITION JOIN $JOIN
		sleep $SLEEP

#		if [ "$JOIN" = "Domain" ]; then
#			ProductID=$( get_config $PARTITION ProductID )
#			dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC}" \
#				--title "\Zb\Z1Partition: $DESC" --nocancel \
#				--inputbox "Geben Sie die Product-ID (Windows-Seriennummer) ein" 10 60 "$ProductID" 2> /tmp/out
#			ProductID=`cat /tmp/out`
#			set_config $PARTITION ProductID $ProductID
#			sleep $SLEEP
#		fi
		if [ -e /mnt/itool/images/$HW/$PARTITION.img ]; then
			backup_image /mnt/itool/images/$HW/$PARTITION.img
		fi
	    ;;
	    Data)
		FORMAT=$( get_config $PARTITION FORMAT )
		msdos="off"; vfat="off"; ntfs="off"; ext2="off"; ext3="off"; swap="off"; clone="off"; no="off";
		case $FORMAT in
		    msdos)	msdos="on";;
		    vfat)	vfat="on";;
		    ntfs)	ntfs="on";;
		    ext2)	ext2="on";;
		    ext3)	ext3="on";;
		    swap)	swap="on";;
		    clone)	clone="on";;
		    no)         no="on";;
		esac
	        dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--title "\Zb\Z1Partition: $DESC" --nocancel \
	       --radiolist "Formatierung der Datenpartition" 16 60 9 \
			msdos "Formatieren: Windows FAT 16"    $msdos \
			vfat  "Formatieren: Windows FAT 32"    $vfat  \
			ntfs  "Formatieren: Windows NTFS"      $ntfs \
			ext2  "Formatieren: Linux ext2"        $ext2 \
			ext3  "Formatieren: Linux ext3"        $ext3 \
			swap  "Formatieren: Linux swap"        $swap \
			clone "1 zu 1 Kopie"                   $clone \
			no    "Nicht formatieren" $no 2> /tmp/out
	        FORMAT=`cat /tmp/out`
	        set_config $PARTITION FORMAT $FORMAT
		if [ FORMAT = "clone" -a  -e /mnt/itool/images/$HW/$PARTITION.img ]; then
			backup_image /mnt/itool/images/$HW/$PARTITION.img
		fi
	        sleep $SLEEP
	    ;;
	esac
	#Which tool we want to use
	partclone="off"; partimage="off"; dd="off"; dd_rescue="off";
	TOOL=$( get_config $PARTITION ITOOL)
	case $TOOL in
	    partclone)	partclone="on";;
	    partimage)	partimage="on";;
	    dd)		dd="on";;
	    dd_rescue)	dd_rescue="on";;
	    *)
		partclone="on";;
	esac
        dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
                --title "\Zb\Z1Partition: $DESC" --nocancel \
                --radiolist "Waehlen Sie das Imagingtool fuer die Partition:" 18 60 8 \
                partclone "Partclone"         $partclone \
                partimage "Partimage"         $partimage \
                dd     "dd 1 zu 1 Kopie"   $dd \
                dd_rescue "dd_rescue"         $dd_rescue  2> /tmp/out
	TOOL=`cat /tmp/out`
	set_config $PARTITION ITOOL $TOOL
        cp /tmp/out /mnt/itool/images/$HW/$PARTITION.tool
        sleep $SLEEP

	i=$((i+1))
    done

    return 0

}

clone()
{
    #Save the master boot record and the partition settings of the drivers
    mkdir -p /mnt/itool/images/$HW/$PARTITION-Unattended/

    if [ ! -d /mnt/itool/images/$HW/$PARTITION-Unattended/ ]
    then
        dialog --colors --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" --title "\Zb\Z1Error" --msgbox "Der angemeldete Benutzer hat keine Rechte in /srv/itool/images." 10 70
	return
    fi

    for HD in $HDs
    do
        dd of=/mnt/itool/images/$HW/$HD.mbr if=/dev/$HD count=2048 bs=512 > /dev/null 2>&1
	PTTYPE=$(  parted -m -s /dev/$HD print | gawk -F : 'NR==2 { print  $6 }' )
	case $PTTYPE in
	    gpt)
	      parted -m -s /dev/$HD unit s print > /mnt/itool/images/$HW/$HD.parted
	      ;;
	    *)
	      sfdisk -d /dev/$HD > /mnt/itool/images/$HW/$HD.sfdisk
	      ;;
	esac
    done

    #Now we save the selected partitions
    for PARTITION in `cat /tmp/partitions`
    do
	OS=$( get_config $PARTITION OS )
	JOIN=$( get_config $PARTITION JOIN)
	if [ "$OS" = "Data" ]; then
	    FORMAT=$( get_config $PARTITION FORMAT)
	    if [ $FORMAT = 'clone' ]; then
	        CTOOL=$( get_config $PARTITION ITOOL)
		saveimage $PARTITION /mnt/itool/images/$HW/$PARTITION.img $CTOOL
	    fi
	else
	    CTOOL=$( get_config $PARTITION ITOOL)
            saveimage $PARTITION /mnt/itool/images/$HW/$PARTITION.img $CTOOL
	    chmod 775 /mnt/itool/images/$HW/$PARTITION.img
	fi
	sleep $SLEEP
        milestone "End clone $PARTITION"
	make_autoconfig
	sleep $SLEEP
    done
}

# Functions for restore
## Get the list of the partitions

get_cloned_partitions()
{
    curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/partitions" >  /tmp/partitions
}

mbr()
{
    for HD in $HDs
    do
        dd if=/mnt/itool/images/$HW/$HD.mbr of=/dev/$HD count=2048 bs=512 > /dev/null 2>&1
    done
}

initialize_disks()
{
    for HD in $HDs
    do
        echo "dd if=/mnt/itool/images/$HW/$HD.mbr of=/dev/$HD count=2048 bs=512"
        dd if=/mnt/itool/images/$HW/$HD.mbr of=/dev/$HD count=2048 bs=512
	sleep 5
	if [ -e /mnt/itool/images/$HW/$HD.sfdisk ]
	then
		echo "sfdisk --force /dev/$HD < /mnt/itool/images/$HW/$HD.sfdisk"
		sfdisk --force /dev/$HD < /mnt/itool/images/$HW/$HD.sfdisk
	fi
    done
    #Activate swap partitions
    for i in $( fdisk -l | grep -i 'Linux swap' | gawk '{ print $1}' )
    do
        mkswap $i
    done
    milestone "End initialize_disks $PARTITION"
}

select_partitions_to_restore()
{
    get_cloned_partitions

    # This funcitons get the list of the avaiable partitions
    echo -n "dialog --colors --backtitle \"CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}\" --title \"Zur Verfuegung stehende Partitionen\" --checklist \"Waehlen Sie die zu bearbeitende Partitionen\" 18 60 8 " > /tmp/command
    for PARTITION in `cat /tmp/partitions`
    do
   DESC=$( get_config $PARTITION DESC )
	echo -n "$PARTITION '$DESC' on " >> /tmp/command
    done
    echo -n " 2> /tmp/partitions"  >> /tmp/command
    . /tmp/command
    if [ $? -ne 0 ]; then
         rm /tmp/partitions
    fi
    sed -i 's#"##g'     /tmp/partitions
}

make_autoconfig()
{
	OS=$( get_config $PARTITION OS)
	mkdir -p /mnt/$PARTITION
	case $OS in
	    Win*)
		mount -o rw /dev/$PARTITION /mnt/$PARTITION

		sleep 1
		MOUNTED=$( mount | grep /mnt/$PARTITION )
		if [ -z "$MOUNTED" ]; then # We need the Presslufthammer!
		    /usr/bin/ntfs-3g -o force,rw /dev/$PARTITION /mnt/$PARTITION
		fi
		JOIN=$( get_config $PARTITION JOIN)
	        ProductID=$( get_config $PARTITION ProductID)
		if [ -e /mnt/itool/config/${OS}${JOIN}.xml ]; then
		    cp /mnt/itool/config/${OS}${JOIN}.xml /mnt/$PARTITION/Windows/Panther/Unattend.xml
		    sed -i "s/HOSTNAME/${HOSTNAME}/"      /mnt/$PARTITION/Windows/Panther/Unattend.xml
		    sed -i "s/PRODUCTID/$ProductID/"      /mnt/$PARTITION/Windows/Panther/Unattend.xml
		    sed -i "s/DOMAIN/${DOMAIN}/"          /mnt/$PARTITION/Windows/Panther/Unattend.xml
		fi
		if [ -e /mnt/$PARTITION/script/ ]; then
                    rm -r /mnt/$PARTITION/script/
                fi
	    ;;
	    Linux|Data)
		mount -o rw /dev/$PARTITION /mnt/$PARTITION
	    ;;
	    *)
	    ;;
	esac
	SALTCONF="/mnt/${PARTITION}/salt/conf";
	if [ -e /mnt/${PARTITION}/etc/salt/conf ]; then
		SALTCONF=/mnt/${PARTITION}/etc/salt/conf
	fi
        if [ -d ${SALTCONF} ]; then
	    sed -i "s/^id:.*/id: ${HOSTNAME}.${DOMAIN}/" ${SALTCONF}/minion
	    sed -i "s/^master:.*/master: ${SERVER}/"     ${SALTCONF}/minion
	    rm -f ${SALTCONF}/pki/minion/*
	    #Reset the minions ssh on the server
	    curl --insecure -X PUT --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/resetMinion"
	fi
	# If a postscript for this partition exist we have to execute it
	if [ -e /mnt/itool/images/$HW/$PARTITION-postscript.sh ]; then
	    . /mnt/itool/images/$HW/$PARTITION-postscript.sh
	fi
        milestone "End  make_autoconfig $PARTITION"
	umount /dev/$PARTITION
}

restore_partitions()
{
     for PARTITION in `cat /tmp/partitions`
     do
	OS=$( get_config $PARTITION OS)
	if [ $OS = 'Data' ]; then
	   FORMAT=$( get_config $PARTITION FORMAT)
		case $FORMAT in
			msdos|vfat|ntfs|ext2|ext3)
				/sbin/mkfs.$FORMAT /dev/$PARTITION
			;;
			swap)
				/sbin/mkswap /dev/$PARTITION
			;;
			clone)
				restore /dev/$PARTITION /mnt/itool/images/$HW/$PARTITION.img
			;;
		esac
	elif [ -e /mnt/itool/images/$HW/$PARTITION.img ]; then
		restore /dev/$PARTITION /mnt/itool/images/$HW/$PARTITION.img
	else
		dialog --colors  --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--title "\Zb\Z1Ein Fehler ist aufgetreten:" \
			--msgbox "Die Imagedatei existiert nicht:\n //${SERVER}/itool/images/$HW/$PARTITION.img" 17 60
	fi
	sleep $SLEEP
        milestone "End  restore_partitions $PARTITION"
	cls
	make_autoconfig
	sleep $SLEEP
     done
}

####################################################
#
# Now we start the cloning programm
#
###################################################

## Set some variables
if [ -z "$SLEEP" ]; then
        SLEEP=1
fi

. /tmp/credentials
. /tmp/apiparams

mount -t cifs -o credentials=/tmp/credentials //${SERVER}/itool /mnt/itool

echo "HOSTNAME ${HOSTNAME}"
# Check if I'm Master
MASTER=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/isMaster" )
echo "MASTER $MASTER"

# Get my conf value if not defined by the kernel parameter
if  [ -z "$HW" ]; then
    HW=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/hwconf" )
fi

echo "HW $HW"

if [ -z "$HW" ]; then
        dialog --colors  --backtitle "CloneTool - ${IVERSION} ${HOSTNAME}" \
                --title "\Zb\Z1Ein Fehler ist aufgetreten:" \
                --msgbox "Diesr Rechner hat keine Rechnerkonfiguration.\nBitte Rechnerkonfiguration setzten und\nRechner erneut in CloneTool starten.\n\nSo kann der Rechner nur manuell kann geklont werden." 17 60
else
        #Get my configuration description
        HWDESC=$(curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/$HW/description")
        echo "HWDESC $HWDESC"

fi

## Get the list of the harddisks
rm -rf /tmp/devs
mkdir -p /tmp/devs
HDs=$( gawk '{if ( $2==0 ) { print $4 }}' /proc/partitions | grep -v loop. )

## Get the DOMAIN
DOMAIN=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/domainName" )
echo "DOMAIN $DOMAIN"

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

	if [ "$MASTER" = "true" ] ;then
		dialog  --colors --help-button --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--nocancel --title "\Zb\Z1Hauptmenu" \
			--menu "Waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Restore"    "Computer wiederherstellen" \
			"Partition"  "Bestimmte Partitionen wiederherstellen" \
			"Clone"      "Rechner klonen" \
			"MBR"        "Master Boot Record wiederherstellen" \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Bash"       "Starte root-Shell (nur fuer Experten)"\
			"Quit"       "Beenden"\
			"About"      "About" 2> /tmp/clone.input
	elif [ -z "$HW" ]; then
		dialog  --colors --help-button --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--nocancel --title "\Zb\Z1Hauptmenu" \
			--menu "Waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Bash"       "Starte root-Shell (nur fuer Experten)"\
			"Quit"       "Beenden"\
			"About"      "About" 2> /tmp/clone.input
	else
		dialog  --colors --help-button --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
			--nocancel --title "\Zb\Z1Hauptmenu" \
			--menu "Waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Restore"    "Computer wiederherstellen" \
			"Partition"  "Bestimmte Partitionen wiederherstellen" \
			"MBR"        "Master Boot Record wiederherstellen" \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
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
		Bash)
			## Menu Item Bash ##
			/bin/bash
		;;
		Quit)
			## Menu Item Quit ##
			dialog --colors  --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
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
			dialog --colors  --backtitle "CloneTool - ${IVERSION} ${HWDESC} ${HOSTNAME}" \
				--title "\Zb\Z1About" \
				--msgbox "${ABOUT}\n Hostname : ${HOSTNAME}\n Festplatte(n): $HDs\n MAC-Adresse: ${MAC}" 17 60
		;;
	esac

done
