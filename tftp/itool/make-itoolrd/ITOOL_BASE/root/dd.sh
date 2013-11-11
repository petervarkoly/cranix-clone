###############################################################################
# Script:       clone.sh
# Copyright (c) 2010 Peter Varkoly, Fuerth, Germany.
# All rights reserved.
#
# Authos:               Peter Varkoly
#
# Description:          Cloning tool for cloning more partitions
#
                                IVERSION="3.1.1"

                                IBUILD="5. December 2010"
#
###############################################################################
#savecmd="/usr/sbin/partimage -z1 -f3 -V0 -o -d --batch save "
savecmd="/bin/dd_rescue -y 0 -a "

#restore="/usr/sbin/partimage -f3 --batch restore "
restore="/bin/dd_rescue -y 0 "

partimage="/usr/sbin/partimage"

ABOUT="OpenSchoolServer-CloneTool\n\n
Ein Werkzeug zum sichern und wiederherstellen von Computern.\n\n
Version: ${IVERSION}\n
Autor  : Peter Varkoly\n
Datum  : ${IBUILD}\n

";


#########################
# Some helper commands
#########################
cls ()
{
    echo -en "\033cl"
}

restart()
{
	umount /mnt/itool
	reboot -f
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
        dialog --backtitle "CloneTool - ${IVERSION} ${HWDESC}" --title "Help for $1" --msgbox "${HELP}" 10 70
}


select_room()
{
   ROOMS=$( ldapsearch -x -LLL '(&(Objectclass=SchoolRoom)(!(cn=Room-1))(description=*))' description | grep description | sed 's/description: //' )
   SELECTROOM="";
   for i in $ROOMS
   do
       SELECTROOM="$SELECTROOM $i -"
   done
   dialog --backtitle "CloneTool - ${IVERSION}" --title "Liste der vorhandenen Raumen" --menu "Waehlen Sie den Raum"  18 60 8 $SELECTROOM 2> /tmp/out
   ROOM=`cat /tmp/out | sed s/\"//g`
   HW=$(ldapsearch -LLL -x "(&(Objectclass=SchoolRoom)(description=$ROOM))" configurationValue | grep 'configurationValue: HW=' | sed 's/configurationValue: HW=//')
   #Now we start an LMD session:
   SESSIONID=$(wget --no-check-certificate --output-document=- "https://admin/cgi-bin/dispatch.pl?username=$USERNAME&userpassword=$PASSWORD&ACTION=LOGIN&login=Login" | grep /SESSIONID / | sed 's/SESSIONID //')
   WORKSTATIONS=$(wget --no-check-certificate --output-document=- "https://admin/cgi-bin/dispatch.pl?SESSIONID=$SESSIONID&APPLICATION=ManageRooms&ACTION=addNewPC&line=edv" | gawk '/^workstations/ { print $2 " - \\" }')
   dialog --backtitle "CloneTool - ${IVERSION}" --title "Liste der vorhandenen Rechner" --menu "Waehlen Sie den Rechner"  18 60 8 $WORKSTATIONS 2> /tmp/out
   HOST=`cat /tmp/out`
   DHCPCDINFO=`ls /var/lib/dhcpcd/dhcpcd-*.info`
   . $DHCPCDINFO
   RESULT=$(wget --no-check-certificate --output-document=- "https://admin/cgi-bin/dispatch.pl?SESSIONID=$SESSIONID&APPLICATION=ManageRooms&ACTION=addPC&workstations=$HOST&hwaddresses=$HWADDR" )
   return =$(echo $RESULT | grep /##ERROR##/)
}

#####################################
# manual backup restore of partitions
#####################################
man_part()
{
   fdisk -l 2>/dev/null | grep '^/dev/' | sed 's/*//' | sed 's/+//' > /tmp/fdiskl
   sed -i 's/W95 /W95-/g' /tmp/fdiskl
   sed -i '/Linux swap/d' /tmp/fdiskl
   sed -i '/Ext/d'  /tmp/fdiskl
   sed -i 's/  */:/g' /tmp/fdiskl
   gawk -F : '{ printf("\"%s\" \"%iMB %s\" ",$1,$4/1024,$6) }' /tmp/fdiskl > /tmp/partitions
   echo -n 'dialog --backtitle "CloneTool - '${IVERSION}'" --title "Manuelles Backup/Restore einer Partition" --menu  "Zur Verfuegung stehende Partitionen:" 20 50 8 ' > /tmp/command
   cat /tmp/partitions >> /tmp/command
   echo ' 2> /tmp/itool.input' >> /tmp/command
   . /tmp/command
   if [ $? -ne 0 ]; then
        return
   fi
   PARTITION=$(cat /tmp/itool.input)

   dialog --backtitle "CloneTool - ${IVERSION}" --title "Manuelles Backup/Restore einer Partition" \
          --menu "Bitte waehlen Sie den gewuenschten modus" 20 50 4 "Backup" "Partition speichern" "Restore" "Partition wiederherstellen" 2> /tmp/itool.input
   if [ $? -ne 0 ]; then
        return
   fi
   MODE=$(cat /tmp/itool.input)

   if [ $MODE = "Backup" ]; then
        dialog --backtitle "CloneTool - ${IVERSION}" --title "Manuelles Backup einer Partition" \
               --inputbox "Bitte geben Sie einen Namen fuer das Image ein:\nDer Name darf nur folgende Zeichen erhalten a-Z1-9_." 10 60 2> /tmp/itool.input
        if [ $? -ne 0 ]; then
                return
        fi
        NAME=$(cat /tmp/itool.input)
        # make it sure the directory do exists
        mkdir -p /mnt/itool/images/manual/
        # now we start partimage
        $savecmd $PARTITION /mnt/itool/images/manual/$NAME.img
	chmod 775 /mnt/itool/images/manual/$NAME.img
        sleep 10
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
            dialog --backtitle "CloneTool - ${IVERSION}" --title "Warnung" --msgbox "Es sind keine manuell erstellten Images auf dem Server vorhanden!" 10 70
            return
        fi
        echo -n 'dialog --backtitle "CloneTool - '${IVERSION}'" --title "Manuelles Backup/Restore einer Partition" --menu  "Zur Verfuegung stehende Images:" 20 70 8 ' > /tmp/command
        cat /tmp/manual >> /tmp/command
        echo ' 2> /tmp/itool.input' >> /tmp/command
        . /tmp/command
        NAME=$(cat /tmp/itool.input)
        if [ $? -ne 0 ]; then
                return
        fi
        dialog --backtitle "CloneTool - ${IVERSION}" --title "Manuelles Backup einer Partition" \
               --infobox "Partimage wird gestartet. Bitte warten!" 10 60
        $restore /mnt/itool/images/manual/$NAME.img /dev/$PARTITION
   fi
}

select_partitions()
{
    # This funciton get the list of the avaiable partitions and starts an
    # checklist dialog to select the partitions to clone or to restore.
    # This will be saved into the file /tmp/partitions
    fdisk -l 2>/dev/null | grep '^/dev/' | sed 's/*//' | sed 's/+//' > /tmp/fdiskl
    sed -i 's/W95 /W95-/g' /tmp/fdiskl
    sed -i '/Linux swap/d' /tmp/fdiskl
    sed -i '/Ext/d'  /tmp/fdiskl
    sed -i 's/  */:/g' /tmp/fdiskl
    sed -i 's#/dev/##g' /tmp/fdiskl
    echo -n "" > /tmp/partitions
    for i in `cat /tmp/fdiskl`
    do
        part=$( echo "$i" | gawk -F : '{ print $1 }' )
	desc=$( get_ldap $part DESC )
	if [ "$desc" ]; then
	    echo -n "$part \"$desc\" on " >> /tmp/partitions
	else
    	    echo $i | gawk -F : '{ printf("%s \"%iMB %s\" on ",$1,$4/1024,$6) }' >> /tmp/partitions
	fi
    done
    echo -n "dialog --backtitle \"OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}\" --title \"Zur Verfuegung stehende Partitionen\" --checklist \"Waehlen Sie die zu bearbeitende Partitionen\" 18 60 8 " > /tmp/command
    cat /tmp/partitions >> /tmp/command
    echo ' 2> /tmp/partitions' >> /tmp/command
    . /tmp/command
    if [ $? -ne 0 ]; then
         return 1
    fi
    sed -i 's#"##g'     /tmp/partitions
    sleep $SLEEP
    return 0
}

save_hw_info()
{
    if [ ! -e /mnt/itool/hwinfo/$HOSTNAME ]; then 
	mkdir -p /mnt/itool/hwinfo/$HOSTNAME
	let i=100
        hw_items="bios cdrom chipcard cpu disk gfxcard keyboard memory monitor mouse netcard printer sound storage-ctrl"
        for hwitem in $hw_items
        do
	    echo $(($i/14)) | dialog --sleep 1 --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" --title "Status" --gauge "Hardwarekonfiguration wird gespeichert: $hwitem"  10 60
            hwinfo --$hwitem > /mnt/itool/hwinfo/$HOSTNAME/$hwitem
	    i=$((i+100))
        done
    fi
}

# Get oss sysconfig value
get_sysconfig()
{
   ldapsearch -x -LLL configurationKey=$1 | grep 'configurationValue: ' | sed 's/configurationValue: //'
}

# Get the necessary configuration values from ldap
# get_ldap Partition Variable
get_ldap()
{
    ldapsearch -x -LLL -b $HWDN -s base "configurationValue=PART_$1_$2*" | grep -i "configurationValue: PART_$1_$2=" | sed "s/configurationValue: PART_$1_$2=//"
}

# Add the necessary configuration values to ldap
# add_ldap Partition Variable "Value"
add_ldap()
{
    echo "dn: $HWDN" > /tmp/ldap_modify
    IFS=$'\n'
    echo $( get_ldap $1 $2 )
    for OLD in $( get_ldap $1 $2 )
    do 
        echo "delete: configurationValue"          >> /tmp/ldap_modify
        echo "configurationValue: PART_$1_$2=$OLD" >> /tmp/ldap_modify
        echo "-" >> /tmp/ldap_modify
    done
    if [ "$3" ]; then
	echo "add: configurationValue" 		>> /tmp/ldap_modify
	echo "configurationValue: PART_$1_$2=$3" 	>> /tmp/ldap_modify
    fi

    ldapmodify -x -D $BINDDN -w $PASSWORD -f /tmp/ldap_modify
    unset IFS
}

get_info()
{
    # Get the description of the partitions
    echo -n "dialog  --backtitle \"OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}\" --title \"Beschreibung der Partitionen\" " >  /tmp/getdescriptions
    echo -n "--form \"Geben Sie eine kurze Beschreibung fuer die Partitionen\" 20 60 10 " 			>> /tmp/getdescriptions 
    let j=1
    for i in `cat /tmp/partitions`
    do
        desc=$( get_ldap $i DESC )
        if [ "$desc" ]; then
            echo -n "$i $j 1 \"$desc\" $j 15 29 20 " >> /tmp/getdescriptions
        else
	    echo -n "$j:" > /tmp/myparts
    	    grep "${i}:" /tmp/fdiskl >> /tmp/myparts
    	    gawk -F : '{ printf("\"%s\" %i 1 \"%iMB %s\" %i 15 20 20 ",$2,$1,$5/1024,$7,$1) }' /tmp/myparts   >> /tmp/getdescriptions
	fi
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
	add_ldap $PARTITION DESC "$DESC"
	OS=$( get_ldap $PARTITION OS )
	Win2K="off"; WinXP="off"; Win7="off"; Linux="off"; Data="off";
	case $OS in
	    Win2K) Win2K="on";;
	    WinXP) WinXP="on";;
	    Win7)  Win7="on";;
	    Linux) Linux="on";;
	    Data) Data="on";;
	esac    

        dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
		--title "Waehlen Sie das Betriebsystem" --nocancel \
		--radiolist "Partition: $DESC" 18 60 8 \
		Win2K    "Windows 2000"         $Win2K \
		WinXP    "Windows XP"           $WinXP \
		Win7     "Windows 7"            $Win7 \
		Linux    "Linux"                $Linux \
		Data     "Partition fuer Daten" $Data 2> /tmp/out
	OS=`cat /tmp/out`
	add_ldap $PARTITION OS $OS
        sleep $SLEEP
	
	case $OS in
	    Win*)
		JOIN=$( get_ldap $PARTITION JOIN )
		Simple="off"; Domain="off"; Workgroup="off"; No="off";
		case $JOIN in
		    Simple)     Simple="on";;
		    Domain)     Domain="on";;
		    Workgroup)  Workgroup="on";;
		    no)         No="on";;
		esac    
	        dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
			--title "Windows Anmeldung" --nocancel \
	        	--radiolist "Partition: $DESC" 11 60 4 \
			Simple    "Windows Domainenmitglied ohne Sysprep"  $Simple \
			Domain    "Windows Domainenmitglied"               $Domain \
			Workgroup "Windows Workgroupmitglied"              $Workgroup \
			no	  "Keine Aufnahme"                         $No 2> /tmp/out
	        JOIN=`cat /tmp/out`
	        add_ldap $PARTITION JOIN $JOIN
		sleep $SLEEP

		if [ "$JOIN" = "Domain" ]; then 
			ProductID=$( get_ldap $PARTITION ProductID )
			dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
				--title "Geben Sie das ProductID ein" --nocancel \
				--inputbox "Partition: $DESC" 10 60 "$ProductID" 2> /tmp/out
			ProductID=`cat /tmp/out`
			add_ldap $PARTITION ProductID $ProductID
			sleep $SLEEP
		fi
		if [ -e /mnt/itool/images/$HW/$PARTITION.img ]; then
			dialog --backtitle  "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" --title "Backup des alten Images" --nocancel \
			       --menu " $PARTITION speichern? " 20 50 4 "Yes" "Vorhandenes Image speichern" "No" "Vorhandenes Image ueberschreiben" 2> /tmp/itool.input
			if [ $? -ne 0 ]; then
				return
			fi
			BACKUP=$(cat /tmp/itool.input)
			if [ $BACKUP = "Yes" ]; then
				backupname="$(ls --full-time /mnt/itool/images/$HW/$PARTITION.img | gawk '{print $6"-"$7}' | sed s/\.000000000// )-$PARTITION.img"
				mv /mnt/itool/images/$HW/$PARTITION.img /mnt/itool/images/$HW/$backupname
			        dialog --backtitle  "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" --title "Backup des alten Images" --nocancel \
				--msgbox "Das vorhande Abbild wurde unter folgendem Pfad gespeichert:\n/mnt/itool/images/$HW/$backupname" 6 70
			fi
		fi
	    ;;
	    Data)
	        dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
			--title "Formatierung der Datenpartition" --nocancel \
	        	--radiolist "Partition: $DESC" 14 60 7 \
			msdos "Windows FAT 16"    off \
			vfat  "Windows FAT 32"    on  \
			ntfs  "Windows NTFS"      off \
			ext2  "Linux ext2"        off \
			no    "Nicht formatieren" off 2> /tmp/out
	        FORMAT=`cat /tmp/out`
	        add_ldap $PARTITION FORMAT $FORMAT
	        sleep $SLEEP
	    ;;
	esac
	i=$((i+1))
    done

    return 0

}

clone()
{    
    #Save the master boot record and the partition settings of the drivers
    mkdir -p /mnt/itool/images/$HW/$PARTITION-Unattended/
    for HD in $HDs 
    do
        dd of=/mnt/itool/images/$HW/$HD.mbr if=/dev/$HD count=62 bs=512 > /dev/null 2>&1
	sfdisk -d /dev/$HD > /mnt/itool/images/$HW/$HD.sfdisk
    done

    #Now we save the selected partitions
    for PARTITION in `cat /tmp/partitions`
    do
	OS=$( get_ldap $PARTITION OS )
	if [ ! "$OS" = "Data" ]; then
	    if [ "$OS" = "Win7" ]; then
	    	mkdir /mnt/$PARTITION
		mount /dev/$PARTITION /mnt/$PARTITION
		mkdir /mnt/$PARTITION/script/
		cp /mnt/itool/config/Win7SimpleJoin.bat /mnt/$PARTITION/script/domainjoin.bat
		sed -i s/OLDNAME/${HOSTNAME}/ /mnt/$PARTITION/script/domainjoin.bat
		umount /mnt/$PARTITION
	    fi
            $savecmd /dev/$PARTITION /mnt/itool/images/$HW/$PARTITION.img
	    chmod 775 /mnt/itool/images/$HW/$PARTITION.img
	fi
	sleep $SLEEP
	make_autoconfig
	sleep $SLEEP
    done
}

# Functions for restore
## Get the list of the partitions

get_cloned_partitions()
{
    ldapsearch -x -b $HWDN -s base | grep 'configurationValue: PART_' | sed 's/configurationValue: PART_//' | grep '_DESC=' | sed 's/_DESC=.*//' > /tmp/partitions
}

mbr()
{
    for HD in $HDs 
    do
        dd if=/mnt/itool/images/$HW/$HD.mbr of=/dev/$HD count=62 bs=512 > /dev/null 2>&1
    done
}

initialize_disks()
{
    for HD in $HDs 
    do
	sfdisk --force /dev/$HD < /mnt/itool/images/$HW/$HD.sfdisk
        dd if=/mnt/itool/images/$HW/$HD.mbr of=/dev/$HD count=62 bs=512 > /dev/null 2>&1
    done
    #Activate swap partitions
    for i in $( fdisk -l | grep -i 'Linux swap' | gawk '{ print $1}' )
    do
        mkswap $i
    done
}

select_partitions_to_restore()
{
    get_cloned_partitions

    # This funcitons get the list of the avaiable partitions
    echo -n "dialog --backtitle \"OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}\" --title \"Zur Verfuegung stehende Partitionen\" --checklist \"Waehlen Sie die zu bearbeitende Partitionen\" 18 60 8 " > /tmp/command
    for PARTITION in `cat /tmp/partitions`
    do
    	DESC=$( get_ldap $PARTITION DESC )
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
	OS=$( get_ldap $PARTITION OS)
	mkdir -p /mnt/$PARTITION
	case $OS in
	    Win*)
		mount -o rw /dev/$PARTITION /mnt/$PARTITION
		sleep 1
		MOUNTED=$( mount | grep /mnt/$PARTITION )
		if [ -z "$MOUNTED" ]; then # We need the Presslufthammer!
		    /usr/bin/ntfs-3g -o force,rw /dev/$PARTITION /mnt/$PARTITION
		fi
	        # If we do not have to join the domain do nothing else until the post script
		JOIN=$( get_ldap $PARTITION JOIN)
		if [ "$JOIN" = "no" ]; then
		    continue
		fi
	        ProductID=$( get_ldap $PARTITION ProductID)
		if [ $OS = "Win7" ]; then
			if [ -e /mnt/itool/config/${OS}${JOIN}.xml ]; then
			    cp /mnt/itool/config/${OS}${JOIN}.xml /mnt/$PARTITION/Windows/Panther/Unattend.xml
			    sed -i "s/HOSTNAME/$HOSTNAME/"        /mnt/$PARTITION/Windows/Panther/Unattend.xml
			    sed -i "s/PRODUCTID/$ProductID/"      /mnt/$PARTITION/Windows/Panther/Unattend.xml
			    sed -i "s/WORKGROUP/$WORKGROUP/"      /mnt/$PARTITION/Windows/Panther/Unattend.xml
			    #cp /mnt/itool/config/${OS}${JOIN}.xml /mnt/$PARTITION/Unattend.xml
			    #sed -i "s/HOSTNAME/$HOSTNAME/"        /mnt/$PARTITION/Unattend.xml
			    #sed -i "s/PRODUCTID/$ProductID/"      /mnt/$PARTITION/Unattend.xml
			    #sed -i "s/WORKGROUP/$WORKGROUP/"      /mnt/$PARTITION/Unattend.xml
			fi
			if [ ${JOIN} = "Domain" ]; then
				cp /mnt/itool/config/Win7DomainJoin.bat /mnt/$PARTITION/script/domainjoin.bat
				sed -i s/HOSTNAME/${HOSTNAME}/   /mnt/$PARTITION/script/domainjoin.bat
				sed -i s/WORKGROUP/${WORKGROUP}/ /mnt/$PARTITION/script/domainjoin.bat
			fi
			if [ ${JOIN} = "Simple" ]; then
				cp /mnt/itool/config/Win7DomainJoin.bat /mnt/$PARTITION/script/domainjoin-1.bat
				sed -i s/HOSTNAME/${HOSTNAME}/   /mnt/$PARTITION/script/domainjoin-1.bat
				sed -i s/WORKGROUP/${WORKGROUP}/ /mnt/$PARTITION/script/domainjoin-1.bat
				if [ "$MASTER" ]; then
					mv /mnt/$PARTITION/script/domainjoin-1.bat /mnt/$PARTITION/script/domainjoin.bat
				else
					sed -i s/HOSTNAME/${HOSTNAME}/   /mnt/$PARTITION/script/domainjoin.bat
				fi
			fi
		else
			SYSPREP=$( ls /mnt/$PARTITION/ | grep -i sysprep )
			if [ -z $SYSPREP ]; then
			    SYSPREP="SYSPREP"
			fi
			mkdir -p /mnt/$PARTITION/$SYSPREP/i386/\$oem\$/
			for i in /mnt/itool/images/$HW/$PARTITION-Unattended/*
			do
			    cp -p $i /mnt/$PARTITION/$SYSPREP/i386/\$oem\$/	
			done
			if [ -e /mnt/itool/config/${OS}${JOIN}.inf ]; then
			    cp /mnt/itool/config/${OS}${JOIN}.inf /mnt/$PARTITION/$SYSPREP/Sysprep.inf
			    sed -i "s/HOSTNAME/$HOSTNAME/"        /mnt/$PARTITION/$SYSPREP/Sysprep.inf
			    sed -i "s/PRODUCTID/$ProductID/"      /mnt/$PARTITION/$SYSPREP/Sysprep.inf
			    sed -i "s/WORKGROUP/$WORKGROUP/"      /mnt/$PARTITION/$SYSPREP/Sysprep.inf
			fi
		fi
	    ;;
	    Linux)
		mount -o rw /dev/$PARTITION /mnt/$PARTITION
	    ;;
	    Data)
	    	FORMAT=$( get_ldap $PARTITION FORMAT)
		if [ "$FORMAT" != "no" ]; then
		    /sbin/mkfs.$FORMAT /dev/$PARTITION
		fi
		mount -o rw /dev/$PARTITION /mnt/$PARTITION
	    ;;
	    *)
	    ;;
	esac
	# If an postscript for this partition exist we have to execute it
	if [ -e /mnt/itool/images/$HW/$PARTITION-postscript.sh ]; then
	    . /mnt/itool/images/$HW/$PARTITION-postscript.sh
	fi
	umount /dev/$PARTITION
}

restore_partitions()
{
     for PARTITION in `cat /tmp/partitions`
     do
        #If we have a partitionimage we have to restore it
	if [ -e /mnt/itool/images/$HW/$PARTITION.img ]; then
	    if [ "$MULTICAST" ]; then
	       udp-receiver --nokbd 2> /dev/null | gunzip | $restore /dev/$PARTITION stdin
	    else
            	$restore /mnt/itool/images/$HW/$PARTITION.img /dev/$PARTITION
	    fi
	fi
	sleep $SLEEP
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

. /var/lib/dhcpcd/dhcpcd-$NIC.info

MAC=$( echo $DHCPCHADDR | gawk '{ print toupper($1) }' )
MACN=$( echo $MAC | sed "s/:/-/g")

echo "MAC      $MAC"
echo "MACN     $MACN"
echo "HOSTNAME $HOSTNAME"

# Check if I'm Master
MASTER=$(ldapsearch -LLL -x "(&(dhcpHWAddress=ethernet $MAC)(configurationValue=MASTER=yes))" dn)
echo "MASTER $MASTER"

# Get Username and Password
USERNAME=`cat /tmp/username`
PASSWORD=`cat /tmp/userpassword`
# Get my conf value if not defined by the kernel parameter
if  [ -z "$HW" ]; then           
    HW=$(ldapsearch -LLL -x "(dhcpHWAddress=ethernet $MAC)" configurationValue | grep 'configurationValue: HW=' | sed 's/configurationValue: HW=//')
fi
if  [ -z "$HW" ]; then
   cont=1
   while [ $cont=1 ];
   do
	ERROR=$(select_room)
	if [ "$ERROR" ]; then
	        for i in $ERROR
	        do
	            MSG="$MSG\n$i"
	        done
	        MSG="$MSG\n Versuchen Sie es noch einmal?"
	        if( dialog --backtitle "CloneTool - ${IVERSION}" --title "Ein Fehler ist aufgetreten" --yesno "$MSG" 10 60 ); then
	     		cont=1
	        else
			restart
	        fi
	else
		cont=0
	fi
   done
fi           
echo "HW $HW"

#Get my configuration description
HWDESC=$(ldapsearch -x -LLL configurationKey=$HW description | grep 'description:' | sed 's/description: //')
echo "HWDESC $HWDESC"

## Get the DN of the HW configuration
HWDN=`ldapsearch -x -LLL configurationKey=$HW dn | sed 's/dn: //'| sed '/^$/d' | sed 's/^ //' | gawk '{ printf("%s",$1) }'`
echo "HWDN $HWDN"

## Get the list of the harddisks
HDs=`sfdisk -s | gawk -F: ' /dev/ { print $1 }' | sed 's#/dev/##g'` 
echo "HDs $HDs"

## Get the BINDDN
BINDDN=`ldapsearch -x -LLL uid=$USERNAME dn | sed 's/dn: //'| sed '/^$/d' | sed 's/^ //' | gawk '{ printf("%s",$1) }'`
echo "BINDDN $BINDDN"

## Get the WORKGROUP
WORKGROUP=$( ldapsearch -x -LLL configurationkey=SCHOOL_WORKGROUP configurationValue | grep 'configurationValue:' | sed 's/configurationValue: //')
echo "WORKGROUP $WORKGROUP"

# Activating DMA mode
for i in $HDs
do
	hdparm -d1 /dev/$i > /dev/null 2>&1
done
echo "SLEEP $SLEEP"
sleep $SLEEP

# Is hostname defined we save the hardware configuration
if [ "$HOSTNAME" ]; then
    save_hw_info
fi

if [ "$MODUS" = "AUTO" ]; then
    # we only have to repair the MBR
    if [ "$PARTITIONS" = "MBR" ]; then
        mbr
        restart
	exit
    fi
    IFS=","
    for i in $PARTITIONS
    do
    	echo $i >> /tmp/partitions
    done
    unset IFS
    initialize_disks
    restore_partitions
    restart
    exit
fi

###############################
## Start the main dialog
###############################
while :
do

	if [ "$MASTER" ] ;then
		dialog  --help-button --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
			--nocancel --title "Hauptmenu" \
			--menu "Bitte waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Restore"    "Computer wiederherstellen" \
			"Partition"  "Bestimmte Partitionen wiederherstellen" \
			"Clone"      "Rechner klonen" \
			"MBR"        "Master Boot Record wiederherstellen" \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Partimage"  "Starte Partimage (nur fuer Experten)"\
			"Quit"       "Beenden"\
			"About"      "About" 2> /tmp/clone.input
	else
		dialog  --help-button --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
			--nocancel --title "Hauptmenu" \
			--menu "Bitte waehlen Sie den gewuenschten Modus" 20 70 12 \
			"Restore"    "Computer wiederherstellen" \
			"Partition"  "Bestimmte Partitionen wiederherstellen" \
			"MBR"        "Master Boot Record wiederherstellen" \
			"Manual"     "Manuelles Backup/Restore einer Partition" \
			"Partimage"  "Starte Partimage (nur fuer Experten)"\
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
		Partimage)
			## Menu Item Partimage ##
			${partimage}
		;;
		Quit)
			## Menu Item Quit ##
			dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
				--title     "Beenden" \
				--ok-label  "Neu starten" \
				--extra-button --extra-label "Herunterfahren" \
				--cancel-label "Abbrechen" \
				--menu      "\nMoechten Sie das Clone Tool wirklich verlassen?\n\n\n " 15 60 1\
				            "" "> Aktuell verbunden mit ${SERVER} <"

			case $? in
			0)
				restart
				exit
			;;
			3)
				umount /mnt/itool
				poweroff -f
				exit
			;;
			*)
			esac
		;;
		About)
                	## Menu Item About ##
			dialog  --backtitle "OpenSchoolServer-CloneTool - ${IVERSION} ${HWDESC}" \
				--title "About" \
				--msgbox "${ABOUT}\n Hostname : ${HOSTNAME}\n Netzwerkkarte : ${NIC} : ${MAC}\n Festplatte(n): $HDs" 17 60
		;;
	esac

done
