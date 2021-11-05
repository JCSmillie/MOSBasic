#!/bin/zsh

################################################################
#
#	lostmodefun.sh  
#		Script takes input of asset tag and then enables or disables
#		lost mode.. also play sound depending on the prefix given.
#
#		JCS - 9/30/2021  -v1
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="LostMode<$2>"

echo "Variable 1-> $1"
echo "Variable 2-> $2"
echo "Variable 3-> $3"
echo "Variable 4-> $4"


#############################
#        Functions          #
#############################
EnableLostMode() {
	#Run Parsing Routine to get fields from tab delimited data
	# ParseIt
	
	#echo "UDID--> $UDID"
	MessagetoSend="Please take this device to the main office or call the GatorIT HelpDesk!"
	phonenumber="Outside-> 412-373-5870 option 4 /  x15108 <-Inside"
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"enable\",\"message\":\"$MessagetoSend\",\"phone_number\":\"$phonenumber\"}]}"

	APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode')

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')

	if [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"
	
	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

PlayLostSound() {
	#Run Parsing Routine to get fields from tab delimited data
	# ParseIt
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"play_sound\"}]}"
	APIOUTPUT=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode')


	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
	echo "$CMDStatus"
	
	if [ "$CMDStatus" = "LOSTMODE_NOTENABLED" ]; then
		echo "API Says iPad is not currently in Lost Mode.  Enabling."
		
		#call enable Lost Mode Routine.
		EnableLostMode
		
	elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"
		
	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

# RequestLocation(){
# 	#Run Parsing Routine to get fields from tab delimited data
# 	ParseIt
#
# 	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"request_location\"}]}"
# 	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode'
#
# }

DisableLostMode(){
	# ParseIt
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"disable\"}]}"
	APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode')
	
	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
	if [ "$CMDStatus" = "LOSTMODE_NOTENABLED" ]; then
		echo "API Says iPad is not currently in Lost Mode.  Can't DISABLE.  Call GSD HELPDESK!"
	elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"		
	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

CheckLostMode() {
	#Build Query.  Just asking for current data on last beat, lostmode status, and location data if we can get it.
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"serial_numbers\":[\"$DeviceSerialNumber\"],\"specific_columns\":\"deviceudid,date_last_beat,tags,lostmode_status,longitude,latitude\"}}"

	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices')

	# echo "What we asked for-->> $content"
	# echo "Output->> $output"

	if echo "$output" | grep "DEVICES_NOTFOUND"; then
		log_line "Mosyle doesn't know $DeviceSerialNumber.  Epic Fail."
		UDID="NOTFOUND"

	#If device is ENABLED	
	elif echo "$output" | grep "ENABLED"; then 
		#echo "Lost Mode is enabled."
		#Parse what was returned.
		WHATWEGOTBACK=$(echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"deviceudid":"?(.*?)"?,"date_last_beat":"?(.*?)"?,"tags":"(.*?)","lostmode_status":"?(.*?)"?,"longitude":"?(.*?)","latitude":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5\t\6/' | cut -d ']' -f 1)
		echo "LOST ENABLED--> $WHATWEGOTBACK"
		unset UDID
		
	else
		#Only enabled state gives us more than we need.  All other states we can go with bare minimum
		WHATWEGOTBACK=$(echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"deviceudid":"?(.*?)"?,"date_last_beat":"?(.*?)"?,"tags":"(.*?)","lostmode_status":"?(.*?)",*.*/\1\t\2\t\3\t\4/' | cut -d ']' -f 1)
		echo "ALL OTHER STATUSES--> $WHATWEGOTBACK"
		unset UDID

	fi

	if [ ! "$UDID" = "NOTFOUND" ]; then
		#Cut that up to variables.
		UDID=$(echo "$WHATWEGOTBACK" |  cut -f 1 -d$'\t' )
		LASTBEAT=$(echo "$WHATWEGOTBACK" |  cut -f 2 -d$'\t' )
		TAGS=$(echo "$WHATWEGOTBACK" | cut -f 3 -d$'\t')
		LOSTMODE=$(echo "$WHATWEGOTBACK" |  cut -f 4 -d$'\t' )
		LONGITUDE=$(echo "$WHATWEGOTBACK" |  cut -f 5 -d$'\t' )
		LATITUDE=$(echo "$WHATWEGOTBACK" |  cut -f 6 -d$'\t' )
		
		echo "($UDID) / ($LASTBEAT) / ($TAGS) / ($LOSTMODE) / ($LONGITUDE) / ($LATITUDE)"
		
		
		LASTBEATDATE=$(python -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTBEAT")).strftime('%Y-%m-%d %I:%M:%S %p'))")
		
		#Figure out how many hours ago last beat was
		current_time=$(date +%s)
		current_time=$(expr "$current_time" / 3600 )
		before_time=$(expr "$LASTBEAT" / 3600 )
		hoursago=$(expr "$current_time" - "$before_time" )
	fi
		
}

DisplayCheckdLostModeData() {	
		echo "$DeviceSerialNumber last seen by Mosyle on $LASTBEATDATE"
		
		echo "${Red}--------------------------------------------------${reset}"
		echo "${Blue}UDID=${Green}$UDID${reset}"
		echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
		echo "${Blue}TAGS=${Green}$TAGS${reset}"
		echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
		echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
		echo "${Blue}USERID=${Green}$USERID${reset}"
		echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"
		echo " "
		echo "${Blue}Last Seen (EPOCH)=${Green}$LASTBEAT${reset}"
		echo "${Blue}Last Seen (Date)=${Green}$LASTBEATDATE${reset}"	
		echo "${Blue}Last Seen (Hours Ago)=${Green}$hoursago${reset}"
		echo "${Blue}Lost Mode Status=${Green}$LOSTMODE${reset}"	

		#If we have locational data, show it.
		if [ ! -z "$LONGITUDE" ] && [ ! -z "$LATITUDE" ]; then
			echo "${Blue}Location Data=${Green}$LATITUDE,$LONGITUDE${reset}"
			echo " "
			echo "GO TO THIS LINK TO SEE LOST IPAD LOCATION-> https://maps.google.com/?q=$LATITUDE,$LONGITUDE"

		fi
		
		echo "${Red}--------------------------------------------------${reset}"
	
		#If TAGS variable says null then swap out variable
		#to be nothing.
		if [ "$TAGS" = "null" ] ; then
			TAGS=""
		fi
}


#############################
#          Do Work          #
#############################
#First parse the Tag
if [ -z "$2" ]; then
	cli_log "Need an asset tag to act on.  Come'on man!"
	exit 1
	
else
	TAG_GIVEN="$2"
	SerialFromTag
fi

#Now take our argument and move forward.
if [ "$1" = "--sound" ]; then
	PlayLostSound

elif [ "$1" = "--enable" ]; then
	EnableLostMode
	
elif [ "$1" = "--disable" ]; then
	DisableLostMode
	
elif [ "$1" = "--status" ]; then
	CheckLostMode	
	DisplayCheckdLostModeData
else
	cli_log "Bad arguments given <$1/$2> Try again."
	exit 1
fi

