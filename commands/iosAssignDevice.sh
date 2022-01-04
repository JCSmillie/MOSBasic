#!/bin/zsh
################################################################
#
#	AssignDevice.sh  
#		Script takes input of asset tag, looks up serial, then
#		tells Mosyle to Limbo the device and wipe the device.
#
#		JCS - 10/21/2021  -v1
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"

IFS=$'\n'


CMDRAN="iOSAssignDevice"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#Delete our file of previous scanned devices if it exists
rm -Rf /tmp/Scan2Assign.txt
rm -Rf /tmp/Scan2Assign_Serialz.txt
rm -Rf /tmp/Scan2Assign_ExtraInfo.txt




AssigniPad() {
	#Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"id\":\"$USERNAME_GIVEN\",\"operation\":\"assign_device\",\"serial_number\":\"$RETURNSERIAL\"}]}"
	APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/users')
	
	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"' | tr -d '}]})')

	#DEBUGGING
	#echo "CMD Status--> $CMDStatus"
	#echo "APIOUTPUT---> $APIOUTPUT"

	if [ "$CMDStatus" = "DEVICES_NOTFOUND" ]; then
		cli_log "Device not found in Mosyle.  Can't Assign!"

	elif echo "$APIOUTPUT" | grep -q "UNKNOWN_USER" ; then
			cli_log "User not found in Mosyle.  Can't Assign!"		

	elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
		cli_log "Command was Successful!"
		
	elif echo "$APIOUTPUT" | grep -q "OK" ; then
		cli_log "Command was Successful!"

	else
		MAXASSIGNMENTS=$(echo "$APIOUTPUT" | grep "MAX_ASSIGNMENTS" )

		if [ ! -z "$MAXASSIGNMENTS" ]; then
			cli_log "Device is assigned to someone else already.  ($AssignedUName)"

		else

			cli_log "Command yeilded Unknown Status ($APIOUTPUT)"
			cli_log "$CMDStatus"
		fi
	fi
}


#############################
#          Do Work          #
#############################
#This would be a routine for doing Scan and Go based on $1 equaling --scan
if [ "$1" = "--scan" ]; then

	#prompt User to scan.
	echo "${Green}Please scan an asset tag and then the students name tag."
	echo "When you've scanned them all just press ENTER to give me a blank${reset}"
	
	#Do a loop and keep taking scan data until we get null
	while true; do
		echo "Asset Tag of Device?"
		read scannedin1
		
		if [ -z "$scannedin1" ]; then
			echo "${Green} Last code scanned.  Proceeding."
			break
			
		else
			echo "User to assign to?"
			read scannedin2
		fi
		
		if [ -z "$scannedin2" ]; then
			echo "I didn't get a username for this device.  Try again."
			read scannedin2
			
			echo "$scannedin1,$scannedin2" >> /tmp/Scan2Assign.txt
			
		else
			echo "$scannedin1,$scannedin2" >> /tmp/Scan2Assign.txt
		fi			
	done		

#This would be a routine for doing a bunch of devices from file based on $1 equaling --mass
# and $2 equaling where to find a file.  File would be asset tag per line.
elif [ "$1" = "--mass" ]; then
		echo "MASS ABILITY IS NOT YET READY..  Fail.. for now."

#This Routine is for doing a single asset tag.
#Pull all serials from file and parse to get UDiD numbers.
else 
	TAG_GIVEN="$1"
	USERNAME_GIVEN="$2"

	SerialFromTag

	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
		exit 1
		
		
	else
		#Call function to see if iPad is shared.  If it is we can't assign it.
		IsThisiPadSharedMode
		
		if [ "$ISSHARED" = "TRUE" ]; then
			cli_log "$ASSETTAG is a Shared iPad.  Cannot be assigned.  Skipping."
			break
			
		else
			#Write our single 
			echo "$TAG_GIVEN,$USERNAME_GIVEN" >> /tmp/Scan2Assign.txt
		fi
	fi
			

fi




cat "/tmp/Scan2Assign.txt" | while read line; do
	
	TAG_GIVEN=$(echo "$line"| cut -d "," -f 1 )
	USERNAME_GIVEN=$(echo "$line"| cut -d "," -f 2 )
	
	echo "DEBUG-> This is where we lookup $TAG_GIVEN"
	
	if [ -z "$TAG_GIVEN" ]; then
		echo "DEBUG-> Blank tag <$TAG_GIVEN> scanned.  Skipping."
		break
	fi
	
	#Call function to see if iPad is shared.  If it is we can't assign it.
	IsThisiPadSharedMode
	
	if [ "$ISSHARED" = "TRUE" ]; then
		cli_log "$ASSETTAG is a Shared iPad.  Cannot be assigned.  Skipping."
		break
		
	elif [ -z "$USERNAME_GIVEN" ]; then
		cli_log "I didn't get a username for $TAG_GIVEN.  Skipping."
		break
		
	else
		USERLOOKUP $USERNAME_GIVEN
		
		USERNAME_GIVEN="$Username"
	fi		
	
	SerialFromTag

	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $TAG_GIVEN in cached Mosyle data.  EPIC FAIL${reset}"
		echo "${Red}Skipping $TAG_GIVEN.  EPIC FAIL${reset}"
		
	elif [ -z "$USERNAME_GIVEN" ]; then
		cli_log "Could not find user in lookup routine.  Skipping."
	else
		cli_log "Asset tag $TAG_GIVEN is $RETURNSERIAL which will be assigned to $FirstName $LastName ($USERNAME_GIVEN) at $LocationName"
		echo "$TAG_GIVEN to $FirstName $LastName ($USERNAME_GIVEN) at $LocationName" >> /tmp/Scan2Assign_ExtraInfo.txt
		echo "$RETURNSERIAL,$USERNAME_GIVEN,$TAG_GIVEN" >> /tmp/Scan2Assign_Serialz.txt
	fi
done



 echo "Proceeding to Assign the following:"
 echo "------------------------------------------"
 cat /tmp/Scan2Assign_ExtraInfo.txt

echo "Are you sure <Y/N>"

read shouldwedoit

if [ "$shouldwedoit" = "Y" ]; then
	echo "DOIN IT!"
	
	
	exec 3< /tmp/Scan2Assign_Serialz.txt
	
	until [ $done ]
	do
	    read <&3 myline
	    if [ $? != 0 ]; then
	        done=1
	        continue
	    fi


		RETURNSERIAL=$(echo "$myline" | cut -f1 -d',' | sed 's/[[:space:]]//g')
		USERNAME_GIVEN=$(echo "$myline" | cut -f2 -d',' | sed 's/[[:space:]]//g')
		TAG_GIVEN=$(echo "$myline" | cut -f3 -d',' | sed 's/[[:space:]]//g')


		cli_log "Assigning $TAG_GIVEN ($RETURNSERIAL) to $USERNAME_GIVEN"
		AssigniPad
	done	
	
else
	echo "Its ok... we all get cold feet sometimes...."
	exit 1
fi