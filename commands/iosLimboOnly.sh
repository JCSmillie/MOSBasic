#!/bin/zsh

################################################################
#
#	iosLimboOnly.sh  
#		Script takes input of asset tag, looks up serial, then
#		tells Mosyle to Limbo the device.  NO WIPE.
#
#		JCS - 2/16/2023  -v1
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="iOSLimboOnly"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#Delete our file of previous scanned devices if it exists
rm -Rf /tmp/Scand2Wipe.txt
rm -Rf /tmp/Scand2Wipe_Serialz.txt
rm -Rf /tmp/Scand2WipeLimbo_Serialz.txt


SorterOfiPadz() {
	#Find out if the iPad we are operating on
	#is a Shared mode iPad
	IsThisiPadSharedMode
	
	#if Shared we only want to wipe
	if [ "$ISSHARED" = "TRUE" ]; then
		cli_log "$ASSETTAG is a Shared iPad.  Cant send to Limbo."
	    exit 1
	else
		
		#Otherwise send to Limbo.
		#if this is our first entry just fill the variable
		if [ -z "$LIMBOSetUDiDs" ]; then
			LIMBOSetUDiDs="$UDID"
		else
			#all others are additons to the variable
			LIMBOSetUDiDs=$(echo "$LIMBOSetUDiDs,$UDID")
		fi
	fi
}


#Format for an iPad Data Dump of JSON
Generate_JSON_Bulk2Limbo() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "change_to_limbo",
    	"devices": "$LIMBOSetUDiDs"
	} ]
}
EOF
}


#############################
#          Do Work          #
#############################
#This will only work with a given identifier.  NOT built for mass use.
TAG_GIVEN="$1"

if [ -z "$TAG_GIVEN" ]; then
	cli_log "No tag given to operate on."
	echo "No tag given... can't do anything for you."
	exit 1
fi

#Get the serial number from the tag.
SerialFromTag

if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
	echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
	log_line "TAG_GIVEN-> Cant find in MosyleData.  Epic Fail."
	exit 1

else
	echo "Asset tag $TAG_GIVEN is $RETURNSERIAL."	
	
	#Call Sorter function to seperate out the Shared iPads from regular iPads
	#before we act.  Shared iPads should NEVER be limbo'd before wiping.
	SorterOfiPadz

	#IF we are sending a single ASSET Tag just do it.  Otherwise
	#seek confirmation.
	shouldwedoit="Y"
fi


echo "Proceeding to Limbo the following:"
echo "------------------------------------------"	
echo "Limbo UDIDs-> $LIMBOSetUDiDs"

#Has confirmation been given?  Get it
if [ -z "$shouldwedoit" ]; then
	echo "Are you sure <Y/N>"
	read shouldwedoit
fi


if [ "$shouldwedoit" = "Y" ] || [ "$shouldwedoit" = "y" ]; then

	#At this point we are almost ready to do the wipe and limbo
	if [ ! -z "$LIMBOSetUDiDs" ]; then
		
			echo "Making it So #1."
			#Before starting to grab data lets grab the Bearer Token
			GetBearerToken
			
			# #Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd
			# content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$LIMBOSetUDiDs\",\"operation\":\"change_to_limbo\"}]}"
			# curl  -s -k -X POST -d $content 'https://managerapi.mosyle.com/v2/bulkops'
			
			#This is a new CURL call with JSON data - JCS 11/8/23
			curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
			--header 'Content-Type: application/json' \
				--header "Authorization: Bearer $AuthToken" \
				--data "$(Generate_JSON_Bulk2Limbo)"
			
			

	else
		#If we are here then we got nothing to work on
		echo "No UDIDs are in cache for Limbo and Wipe.  Doing Nothing."
	fi

else
	echo "Its ok... we all get cold feet sometimes...."
	exit 1
fi
