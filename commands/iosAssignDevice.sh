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

#Load IIQ Functions
source "$BAGCLI_WORKDIR/modules/incidentiq.sh"

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





# #Format for an iPad Data Dump of JSON
# Generate_JSON_AssignDevice() {
# cat <<EOF
# 	{"accessToken": "$MOSYLE_API_key",
# 	"elements": [ {
#         "operation": "save",
#     	"id": "$USERNAME_GIVEN",
#         "name": "$FirstName $LastName",
#         "type": "S",
#         "email": "$USERNAME_GIVEN@gatewayk12.net",
#         "locations": [
#             {
#                 "name": "$LocationName",
#                 "grade_level": "$Grade"
#             }
# 			],
#         "welcome_email": 0
# 		}
# 		]
# }
#
# EOF
# }

#Format for an iPad Data Dump of JSON
Generate_JSON_AssignDevice() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "assign_device",
    	"id": "$USERNAME_GIVEN",
        "serial_number": "$RETURNSERIAL"
		}
		]
}
EOF
}


AssigniPad() {
	#Before starting to grab data lets grab the Bearer Token
	GetBearerToken
		
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/users' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_AssignDevice)")
	
	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"' | tr -d '}]})')

	#DEBUGGING
	if [ $"DEBUG" = Y ]; then
		echo "CMD Status--> $CMDStatus"
		echo "APIOUTPUT---> $APIOUTPUT"
		echo "$(Generate_JSON_AssignDevice)"
	fi

	
	if [ "$CMDStatus" = "DEVICES_NOTFOUND" ]; then
		cli_log "Device not found in Mosyle.  Can't Assign!"

	elif echo "$APIOUTPUT" | grep -q "UNKNOWN_USER" ; then
			cli_log "User not found in Mosyle.  Can't Assign!"	
	
	elif echo "$APIOUTPUT" | grep -q "INVALID_DATA" ; then
			cli_log "Bad Data given to API.  Didn't work!"
			echo "$APIOUTPUT >> $LOG"		
				

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
		
		if [ ! -s "$2" ]; then
			echo "${Red}File given ($2) doesn't exist.  EPIC FAIL${reset}"
			exit 1
		else
			echo "File given MUST be in format <tag>,<StudentID>.  Assuming you know what your doing!"
			cat "$2" > /tmp/Scan2Assign.txt
		fi

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
	
	#echo "DEBUG-> This is where we lookup $TAG_GIVEN"
	
	if [ -z "$TAG_GIVEN" ]; then
		echo "${White}Blank tag <$TAG_GIVEN> scanned.  Skipping.{reset}"
		break
	fi
	
	################HAY ME...  WHY AM I DOING THIS TWICE?  SEE ABOVE WHEN TAG AND NAME R GIVEN
	#echo "DEBUG-> This is where we check if iPAd is Shared Mode"
	#Call function to see if iPad is shared.  If it is we can't assign it.
	IsThisiPadSharedMode
	
	if [ "$ISSHARED" = "TRUE" ]; then
		cli_log "${White}$ASSETTAG is a Shared iPad.  Cannot be assigned.  Skipping.{reset}"
		break
		
	elif [ -z "$USERNAME_GIVEN" ]; then
		cli_log "${White}I didn't get a username for $TAG_GIVEN.  Skipping.{reset}"
		break
		
	else
		
		#echo "DEBUG-> This is where we make sure the user exists"
		USERLOOKUP $USERNAME_GIVEN
		
		USERNAME_GIVEN="$Username"
	fi		
	
	#echo "DEBUG-> This is where we try to get the tag from the Serial #"
	SerialFromTag
	
	#If checking Mosyle did nothing for us then lets ask IIQ.
	if [ "$RETURNSERIAL" = "EPICFAIL" ] || [ "$RETURNSERIAL" = "TOOMANYSERIALS" ]; then
		cli_log "Trying to get serial for $TAG_GIVEN from IIQ."
		GetSerialFromTag "$TAG_GIVEN"
	fi
		
	
	
	#Check to see if a return code came back of EPICFAIL from the SerialFromTag function (found in common)
	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $TAG_GIVEN in cached Mosyle data.  EPIC FAIL${reset}"
		echo "${Red}Skipping $TAG_GIVEN.  EPIC FAIL${reset}"
		
	elif [ -z "$USERNAME_GIVEN" ]; then
		cli_log "${Red}Could not find user in lookup routine.  Skipping.${reset}"
	
	#Check to see if a return code came back of TOOMANYSERIALS from the SerialFromTag function (found in common)	
	elif [ "$RETURNSERIAL" = "TOOMANYSERIALS" ]; then
		echo "${Red}Skipping $TAG_GIVEN/$USERNAME_GIVEN.  Bad Serial Lookup.  EPIC FAIL${reset}"
	else
		cli_log "Asset tag $TAG_GIVEN is $RETURNSERIAL which will be assigned to $FirstName $LastName ($USERNAME_GIVEN) at $LocationName"
		echo "$TAG_GIVEN to $FirstName $LastName ($USERNAME_GIVEN) at $LocationName" >> /tmp/Scan2Assign_ExtraInfo.txt
		echo "$RETURNSERIAL,$USERNAME_GIVEN,$TAG_GIVEN" >> /tmp/Scan2Assign_Serialz.txt
	fi
done

#Make sure our data file is not empty.  If it is quit.
if [ ! -s /tmp/Scan2Assign_ExtraInfo.txt ]; then
	echo "No data present to assign.  Doing nothing."
	exit 1
else
	
	
	echo "Proceeding to Assign the following:"
	echo "------------------------------------------"
	cat /tmp/Scan2Assign_ExtraInfo.txt

	#If this was a Mass operation were not asking to confirm
	#were just going to roll through it.  If its not mass then
	#ask for confirmation.
	#Has confirmation been given?  Get it
	if [ ! "$1" = "--mass" ]; then
		echo "Are you sure <Y/N>"
		read shouldwedoit
		
	else
		shouldwedoit="Y"
	fi

	if [ "$shouldwedoit" = "Y" ]; then
		echo "DOIN IT!"
		
		#Make sure our assignment file is not empty.  If it is skip.
		if [ ! -s /tmp/Scan2Assign_Serialz.txt ]; then
			cli_log "No Assign data present to assign.  Doing nothing."
			exit 1
			
		else
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
		fi

	else
		echo "Its ok... we all get cold feet sometimes...."
		exit 1
	fi
fi