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
else
	cli_log "Bad arguments given <$1/$2> Try again."
	exit 1
fi

