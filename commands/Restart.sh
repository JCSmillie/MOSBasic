#!/bin/zsh

################################################################
#
#	restart.sh  
#		Script takes input of asset tag, looks up serial, then
#		tells Mosyle to restart the device.
#
#		JCS - 04/02/2025
#           Enhancements -JCS 10/19/25
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="restart"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#Delete our file of previous scanned devices if it exists
rm -Rf /tmp/Scand2Restart.txt
rm -Rf /tmp/Scand2Restart_Serialz.txt


#############################
#          Do Work          #
#############################
#This will only work with a given identifier.  NOT built for mass use.
TAG_GIVEN="$1"

if [ -z "$TAG_GIVEN" ]; then
	cli_log "No tag given to operate on."
	echo "No tag given... can't do anything for you."
	exit 1
#Try to figure out if we were given a Serial Number or Asset tag
elif [[ "$TAG_GIVEN" =~ ^[0-9]{4,6}$ ]]; then
    TYPE="asset"
    #Get the serial number from the tag.
    SerialFromTag
else
    TYPE="serial"
    cli_log "Serial is already know-> $TAG_GIVEN"
    DeviceSerialNumber="$TAG_GIVEN"
    RETURNSERIAL="$TAG_GIVEN"
    UDID=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$DeviceSerialNumber" | cut -d$'\t' -f1)
    
fi

#Make note of what type we think the data given was.
cli_log "Input type: $TYPE"


#Test RETURNSERIAL.  If it says EPICFAIL (interal note) fail.
if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
	echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
	log_line "TAG_GIVEN-> Cant find in MosyleData.  Epic Fail."
	exit 1

else
	echo "Asset tag $TAG_GIVEN is $RETURNSERIAL."	
	
	#Call Sorter function to seperate out the Shared iPads from regular iPads
	#before we act.  Shared iPads should NEVER be RESTART'd before wiping.
	SorterOfiPadz-blkopz

	#IF we are sending a single ASSET Tag just do it.  Otherwise
	#seek confirmation.
	shouldwedoit="Y"
fi


echo "Proceeding to RESTART the following:"
echo "------------------------------------------"	
echo "RESTART UDIDs-> $blkopzSetUDiDs"

#Has confirmation been given?  Get it
if [ -z "$shouldwedoit" ]; then
	echo "Are you sure <Y/N>"
	read shouldwedoit
fi


if [ "$shouldwedoit" = "Y" ] || [ "$shouldwedoit" = "y" ]; then

	#At this point we are almost ready to do the wipe and RESTART
	if [ ! -z "$blkopzSetUDiDs" ]; then
	
		echo "Making it So #1."
		#Before starting to grab data lets grab the Bearer Token
		GetBearerToken
		
		# #Call out to Mosyle MDM to submit list of UDIDs which need RESTART'd
		OPERATION2PERFORM="restart_devices"
		DEVICES2BULKON="$blkopzSetUDiDs"
		
		#This is a new CURL call with JSON data - JCS 11/8/23            
		APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_BulkOperations)")

		CMDStatus=$(echo "$APIOUTPUT" | grep "COMMAND_SENT")
		
		if [ ! -z "$CMDStatus" ]; then
			echo "Command was Successful!"

		else
			echo "Command yeilded Unknown Status ($APIOUTPUT)"
		fi
		
		#Log that we did something
		cli_log "Bulk command $OPERATION2PERFORM was sent to the following devices: $DEVICES2BULKON"
	else
		#If we are here then we got nothing to work on
		echo "No UDIDs are in cache for RESTART and Wipe.  Doing Nothing."
	fi

else
	echo "Its ok... we all get cold feet sometimes...."
	exit 1
fi

#Check if we need to return JSON.
if $JSON_MODE; then
    # Return JSON for web/PHP caller
    #echo "{\"status\":\"$RESULT\",\"message\":\"$MESSAGE\"}"
	echo "$APIOUTPUT"
fi