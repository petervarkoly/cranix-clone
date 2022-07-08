# (c) Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg
# Functions for the clone tool

auto_login()
{
    echo "username=ossreader" >  /tmp/credentials
    echo "password=ossreader" >> /tmp/credentials
    echo "ossreader" > /tmp/username
    echo "ossreader" > /tmp/userpassword
    chmod 400 /tmp/userpassword
    chmod 400 /tmp/credentials
    . /tmp/credentials
    COUNTER=100
    while [ -z "$TOKEN"  -o "${TOKEN:0:7}" = '{"code"' ]
    do
        TOKEN=$( curl --insecure -X POST --header 'Content-Type: application/x-www-form-urlencoded' --header 'Accept: text/plain' -d "username=$username&password=$password" "https://${SERVER}/api/sessions/login" )
        COUNTER=$((COUNTER-1))
        echo ${TOKEN}
        sleep 1
        if [ ${COUNTER} = 0 ]; then
           break
        fi
    done
    if [ "$TOKEN"  -a "${TOKEN:0:7}" != '{"code"' ]
    then
        HOSTNAME=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/hostName" )
        echo "TOKEN=$TOKEN"         >  /tmp/apiparams
        echo "HOSTNAME=${HOSTNAME}" >> /tmp/apiparams
	WORKGROUP=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/system/configuration/WORKGROUP" )
	echo "domain=${WORKGROUP}"   >> /tmp/credentials
        bash ${CDEBUG} /root/${STARTCMD}.sh
        curl --insecure -X DELETE --header 'Content-Type: application/json' --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/sessions/$TOKEN"
        exit 0
    fi
    dialog  --backtitle "${STARTCMD}" --title "Anmeldung" --yesno "$WARNING" 15 60
    if [ $? -ne 0 ]
    then
        clear
        exit 0
    else
        export MODUS=""
        /root/login
        exit 0
    fi
}

authorization()
{
    while test -e /tmp
    do
        dialog --backtitle "${STARTCMD}" --title "Anmeldung" --cancel-label "Beenden" --inputbox "Bitte geben Sie Ihren Benutzernamen ein:\n" 10 60 2> /tmp/username

        if [ $? -eq 1 ]; then
                clear
                exit 0
        fi
        USERNAME=$(cat /tmp/username)
        USERNAME=$(echo $USERNAME | tr '[:upper:]' '[:lower:]' 2>/dev/null)

        if [ "$USERNAME" = "administrator" -o "$USERNAME" = "admin" ]; then
                USERNAME="Administrator"
        fi
        if [ ! "$USERNAME" ]; then
                dialog --backtitle "${STARTCMD}" --title "Anmeldung" --msgbox "Der Benutzername $USERNAME ist ungueltig!" 15 60
        elif [ "$USERNAME" = "root" ]; then
                dialog --backtitle "${STARTCMD}" --title "Anmeldung" --msgbox "Die Anmeldung an cloneTool als $USERNAME ist nicht möglich!" 15 60
        else
                dialog --backtitle "${STARTCMD}" --title "Anmeldung" --no-cancel \
                       --insecure --passwordbox "Bitte geben Sie das Passwort fuer $USERNAME ein:\n" 10 60 2> /tmp/userpassword
                echo "username=$USERNAME" >  /tmp/credentials;
                echo -n "password="       >> /tmp/credentials; cat /tmp/userpassword >> /tmp/credentials;
		echo "" >> /tmp/credentials
                chmod 400 /tmp/credentials
                chmod 400 /tmp/userpassword
                . /tmp/credentials
                ## GET A SESSION TOKEN
                TOKEN=$( curl --insecure -X POST --header 'Content-Type: application/x-www-form-urlencoded' --header 'Accept: text/plain' -d "username=$username&password=$password" "https://${SERVER}/api/sessions/login" )
                if [ "$TOKEN" -a "${TOKEN:0:7}" != '{"code"' ]; then
			HOSTNAME=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/hostName" )
			WORKGROUP=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/system/configuration/WORKGROUP" )
		        echo "TOKEN=$TOKEN"         >  /tmp/apiparams
		        echo "HOSTNAME=${HOSTNAME}" >> /tmp/apiparams
			echo "domain=${WORKGROUP}"  >> /tmp/credentials
			export TOKEN
                        return
                fi
                sleep $SLEEP
                dialog --backtitle "${STARTCMD}" --title "Anmeldung" --yesno "$WARNING" 15 60
                if [ $? -ne 0 ]; then
                        clear
                        exit 0
                fi
                rm -f /tmp/credentials /tmp/userpassword
        fi
    done
}

register()
{
        #We have to register the workstation
        ON="on"
        ROOMS=''
        for i in $( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/roomsToRegister" )
        do
             j=$( echo $i | sed 's/##/ /' )
             ROOMS="${ROOMS} $j $ON "
             ON="off"
        done
        dialog --backtitle "CloneTool 4.0" --title "Rechner muss registriert werden"  --nocancel --radiolist "Waehlen Sie den gewuenschten Raum" 18 60 8  $ROOMS 2> /tmp/clone.input
        ROOM=$(cat /tmp/clone.input)

        #Get the list of the available devices in the room
        DEVICES=$( curl --insecure -X GET --header 'Accept: text/plain' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/rooms/$ROOM/availableIPAddresses" )
        dialog --backtitle "${CTOOLNAME}" --title "Rechner muss registriert werden"  --nocancel --menu "Waehlen Sie den gewuenschten Rechnernamen" 18 60 8  $DEVICES 2> /tmp/clone.input
        DEVICE=$(cat /tmp/clone.input)

        #Get the active device name
        ETH=$(ip link | grep 'state UP' | gawk '{ print $2 }' | sed 's/://')
        export MAC=$(cat /sys/class/net/$ETH/address )

        #Lets register the device
        RESPONSE=$( curl --insecure -X PUT --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/clonetool/rooms/$ROOM/$MAC/$DEVICE" )
        curl --insecure -X DELETE --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN" "https://${SERVER}/api/sessions/$TOKEN"
        sleep 3
        ifdown $ETH
        sleep 1
        ifup   $ETH
        TOKEN=$( curl --insecure -X POST --header 'Content-Type: application/x-www-form-urlencoded' --header 'Accept: text/plain' -d "username=$username&password=$password" "https://${SERVER}/api/sessions/login" )
        HOSTNAME=$( curl --insecure -X GET --header 'Accept: text/plain' "https://${SERVER}/api/clonetool/hostName" )
        if [ -z "${HOSTNAME}" ]
        then
		dialog --backtitle "${CTOOLNAME}" --title "Registration fehlgeschlagen." --msgbox "Die Regsitrierung des Rechners ist Fehlgeschlagen.\nÜber die Adminoberfläche widerholen!" 17 60
		exit 0
        fi
	echo "TOKEN=$TOKEN" >  /tmp/apiparams
}

