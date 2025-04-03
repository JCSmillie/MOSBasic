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

CMDRAN="LostMode=> $2"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi



#############################
#        Functions          #
#############################
#Format for an iPad Data Dump of JSON
Generate_JSON_LostModeOperations() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "$OPERATION2PERFORM",
    	"devices": "$DEVICES2BULKON",
		"message": "$LOSTMODEMessagetoSend",
		"phone_number": "$LOSTMODEphonenumber",
		"footnote": "$LOSTMODEfootnote"
	} ]
}
EOF
}

EnableLostMode() {
	#Run Parsing Routine to get fields from tab delimited data
	# ParseIt
	# 
 	#Based on hours above color code our output.  Green is 12 hrs or less,
	#Yellow is 24 hrs or less, and red is everything else.
	if [ "$hoursagoLMQ" -lt 12 ]; then
		echo "${Green}Device has checked in to MDM in the last 12 hrs...  Good possibilty this works!${reset}"
	elif [ "$hoursagoLMQ" -lt 24 ]; then
		echo "${Yellow}Device has checked in to MDM in the last 24 hrs...  Fair possibilty this works....${reset}"
	else
		echo "${Red}Device hasn't checked into MDM in over a day..  Milage may very on this attempt....${reset}"	
	fi	
	
	
	#Set Variables in our Call.
	OPERATION2PERFORM="enable"
	DEVICES2BULKON="$UDID"
	
	cli_log "Operation $OPERATION2PERFORM called upon to act on $DEVICES2BULKON"
	
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/lostmode' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostModeOperations)" 2> /dev/null) 
	

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')

	if [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"

	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

PlayLostSound() {
	#Set Variables in our Call.
	OPERATION2PERFORM="play_sound"
	DEVICES2BULKON="$UDID"
	
	cli_log "Operation $OPERATION2PERFORM called upon to act on $DEVICES2BULKON"
		
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/lostmode' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostModeOperations)") 


	# ###DEBUG SHOW STRING SENT TO MOSYLE
	# echo "curl -s -k -X POST -d $content 'https://managerapi.mosyle.com/v2/lostmode'"

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
	echo "$CMDStatus"
	echo "$APIOUTPUT"
	
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

DisableLostMode(){
	#Set Variables in our Call.
	OPERATION2PERFORM="disable"
	DEVICES2BULKON="$UDID"
	
	cli_log "Operation $OPERATION2PERFORM called upon to act on $DEVICES2BULKON"
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/lostmode' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostModeOperations)")	
	
	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
	if [ "$CMDStatus" = "LOSTMODE_NOTENABLED" ]; then
		echo "API Says iPad is not currently in Lost Mode.  Can't DISABLE.  Call GSD HELPDESK!"
	elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"		
	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

DisableLostModeBULK(){
	#Set Variables in our Call.
	OPERATION2PERFORM="disable"
	DEVICES2BULKON="$LIMBOSetUDiDs"
	
	cli_log "Operation $OPERATION2PERFORM called upon to act on $DEVICES2BULKON"
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/lostmode' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostModeOperations)")	
	
	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
	if [ "$CMDStatus" = "LOSTMODE_NOTENABLED" ]; then
		echo "API Says iPad is not currently in Lost Mode.  Can't DISABLE.  Call GSD HELPDESK!"
	elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
		echo "Command was Successful!"		
	else
		echo "Command yeilded Unknown Status ($APIOUTPUT)"
	fi
}

LocateDevice() {
	#Set Variables in our Call.
	OPERATION2PERFORM="request_location"
	DEVICES2BULKON="$UDID"
	
	cli_log "Operation $OPERATION2PERFORM called upon to act on $DEVICES2BULKON"
	
	#This is a new CURL call with JSON data - JCS 11/8/23
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/lostmode' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostModeOperations)")

	###DEBUG SHOW STRING SENT TO MOSYLE
	#echo "curl -s -k -X POST -d $content 'https://managerapi.mosyle.com/v2/lostmode'"

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 3 | cut -d "," -f 1 | tr -d '"')
	
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

Generate_JSON_LostmodeCheck() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"options": {
		"os": "ios",
		"serial_numbers": "$DeviceSerialNumber",
		"specific_columns": "deviceudid,date_last_beat,tags,lostmode_status,longitude,latitude,altitude"
	}
}
EOF
}

CheckLostMode() {
	# #Build Query.  Just asking for current data on last beat, lostmode status, and location data if we can get it.
	APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/listdevices' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_LostmodeCheck)")
	
	echo "$APIOUTPUT"
	echo "SERIAL NUMBER--> $DeviceSerialNumber"


	if echo "$APIOUTPUT" | grep "DEVICES_NOTFOUND"; then
		log_line "Mosyle doesn't know $DeviceSerialNumber.  Epic Fail."
		UDID="NOTFOUND"

	#If device is ENABLED	
	elif echo "$APIOUTPUT" | grep "ENABLED"; then 
		#echo "Lost Mode is enabled."
		#Parse what was returned.
		JSON=$(echo "$APIOUTPUT" | /usr/local/munki/munki-python -m json.tool)		
		
		if [ "$MB_DEBUG" = "Y" ]; then
			echo "LOST ENABLED--> $JSON"
		fi
		
		unset UDID
		
	else
		#Only enabled state gives us more than we need.  All other states we can go with bare minimum
		JSON=$(echo "$APIOUTPUT" | /usr/local/munki/munki-python -m json.tool)
		if [ "$MB_DEBUG" = "Y" ]; then
			echo "ALL OTHER STATUSES--> $JSON"
		fi
		
		unset UDID

	fi

	if [ ! "$UDID" = "NOTFOUND" ]; then
		#Cut that up to variables.

		UDID=$(echo "$JSON" |  grep deviceudid | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2 )
		LASTBEAT=$(echo "$JSON" |  grep date_last_beat | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		TAGS=$(echo "$JSON" | grep tags | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		LOSTMODE=$(echo "$JSON" | grep lostmode_status | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		LONGITUDE=$(echo "$JSON" | grep longitude | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		LATITUDE=$(echo "$JSON" | grep latitude | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		ALTITUDE=$(echo "$JSON" | grep altitude | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)
		
		if [ "$MB_DEBUG" = "Y" ]; then
			echo "($UDID) / ($LASTBEAT) / ($TAGS) / ($LOSTMODE) / ($LONGITUDE) / ($LATITUDE)"
		fi
		
		LASTBEATDATE=$($PYTHON2USE -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTBEAT")).strftime('%Y-%m-%d %I:%M:%S %p'))")
		
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


#Format for an iPad Data Dump of JSON
Generate_JSON_InventoryOperations() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"options": {
		"os": "$PLATFORM2QUERY",
		"page": "$THEPAGE",
		"page_size": "1000",
		"specific_columns": "$SpecificColumns"
	}
}
EOF
}



WHOISLOST() {
	rm -Rf /tmp/LostModeFun.REPORT.txt
	#Initialize the base count variable. This will be
	#used to figure out what page we are on and where
	#we end up.
	THECOUNT=0
	PLATFORM2QUERY="ios"
	SpecificColumns="deviceudid,date_last_beat,tags,lostmode_status"

	Connect to Mosyle API multiple times (for each page) so we
	get all of the available data.
	while true; do
		let "THECOUNT=$THECOUNT+1"
		THEPAGE="$THECOUNT"

		#This is a new CURL call with JSON data - JCS 11/8/23
		APIOUTPUT=$(curl --location 'https://managerapi.mosyle.com/v2/listdevices' \
			--header 'content-type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_InventoryOperations)") >> $LOG


		#Detect we just loaded a page with no content and stop.
		LASTPAGE=$(echo $APIOUTPUT | grep DEVICES_NOTFOUND)
		if [ -n "$LASTPAGE" ]; then
			let "THECOUNT=$THECOUNT-1"
			cli_log "Yo we are at the end of the list (Last good page was $THECOUNT)"
			break
		fi

		#Detect we just loaded a page with no content and stop.
		LASTPAGE=$(echo $APIOUTPUT | grep UNKNOWN_COLUMNS)
		if [ -n "$LASTPAGE" ]; then
			let "THECOUNT=$THECOUNT-1"
			cli_log "Hit error; Unknown Columns (Last good page was $THECOUNT)"
			break
		fi




		FAILURE=$(echo $APIOUTPUT | grep INVALID_JSON)
		if [ -n "$FAILURE" ]; then
			cli_log "I sent bad code to Mosyle.."
			cli_log "Content-> $content"
			break
		fi

		echo " "
		cli_log "Page $THEPAGE data."
		echo "-----------------------"
		#Now take the JSON data we received and parse it into tab
		#delimited output.

		echo "$APIOUTPUT" > /tmp/LostModeFun.$THEPAGE.txt

		#Preprocess the file.  We need to remove {"status":"OK","response": so can do operations with our python json to csv converter.  Yes
		#I know this is still janky but hay I'm getting there.
		cat /tmp/LostModeFun.$THEPAGE.txt  | cut -d ':' -f 3- | sed 's/.$//' > /tmp/LostModeFun.TEMPSPOT.txt
		mv -f /tmp/LostModeFun.TEMPSPOT.txt /tmp/LostModeFun.$THEPAGE.txt

		#Call our python json to csv routine.  Output will be tab delimited so we can maintain our "tags" together.
		$PYTHON2USE $BAGCLI_WORKDIR/modules/json2csv.py devices /tmp/LostModeFun.$THEPAGE.txt /tmp/LostModeFun.REPORT.txt



	done

	#Split up the dump to seperate files to handle seperately
	cat /tmp/LostModeFun.REPORT.txt | grep ENABLED > /tmp/.enabled.lost_ish.txt
	cat /tmp/LostModeFun.REPORT.txt | grep PENDINGTOENABLE > /tmp/.pending2enable.lost_ish.txt
	cat /tmp/LostModeFun.REPORT.txt | grep PENDINGTODISABLE > /tmp/.pending2disable.lost_ish.txt

	#Work the Enabled Pile...
	echo "${Magenta}             Devices Currently IN LOST MODE (ENABLED)${reset}"
	echo "${Blue}-----------********************************************-----------${reset}"
	cat /tmp/.enabled.lost_ish.txt | while read DataFromLostModeQuery; do
		#Fill variables based on data from file
		UDID2LookupLMQ=$(echo "$DataFromLostModeQuery" | cut -f 1 -d$'\t' )
		LASTBEATLMQ=$(echo "$DataFromLostModeQuery" |  cut -f 2 -d$'\t' )
		TAGSLMQ=$(echo "$DataFromLostModeQuery" | cut -f 3 -d$'\t')
		LOSTMODELMQ=$(echo "$DataFromLostModeQuery" |  cut -f 4 -d$'\t' )

		# ##Take Epoch time and convert to a date
		# LASTCHECKINLMQ=$($PYTHON2USE -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTBEATLMQ")).strftime('%Y-%m-%d %I:%M:%S %p'))")



		#Now query our cache'd info to fill in the blanks.
		UDID2Lookup=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$UDID2LookupLMQ")

		#Pass the info we just got to the parse routine.
		line="$UDID2Lookup"
		ParseIt_ios
		
		# echo "DEBUG2-> UDID-> $UDID"
		# echo "DEBUG2-> NAME-> $NAME"
		# echo "DEBUG2-> TAGS-> $TAGS"
		# echo "DEBUG2-> ASSETTAG-> $ASSETTAG"
		# echo "DEBUG2-> LASTCHECKIN-> $LASTCHECKIN"

		if [ -z "$USERID" ]; then
			USERID="NotAss"
			NAME="NOT ASSIGNED"
		fi

		if [ -z "$TAGSLMQ" ]; then
			TAGSLMQ="NO TAGS"
		fi

		#Figure out how many hours ago last beat was
		current_time=$(date +%s)
		current_time=$(expr "$current_time" / 3600 )
		before_time=$(expr "$LASTBEATLMQ" / 3600 )
		hoursagoLMQ=$(expr "$current_time" - "$before_time" )
		
		echo "$UDID2Lookup"

		#Based on hours above color code our output.  Green is day or less, Yellow is 3
		#days or less, and red is everything else.
		# if [ "$hoursagoLMQ" -lt 24 ]; then
		# 	echo "${Green} $ASSETTAG / $LASTCHECKIN / $USERID / $NAME / $TAGS ${reset}"
		# elif [ "$hoursagoLMQ" -lt 72 ]; then
		# 	echo "${Yellow} $ASSETTAG / $LASTCHECKIN / $USERID / $NAME / $TAGS ${reset}"
		# else
		# 	echo "${Red} $ASSETTAG  / $LASTCHECKIN / $USERID / $NAME / $TAGS ${reset}"
		# fi

		#Lets fill a variable of UDIDs to work with later....
		#if this is our first entry just fill the variable
		if [ -z "$PlaySoundUDiDs" ]; then
			PlaySoundUDiDs="$UDID2LookupLMQ"
		else
			#all others are additons to the variable
			PlaySoundUDiDs=$(echo "$PlaySoundUDiDs,$UDID2LookupLMQ")
		fi


	done
	echo " "
	echo " "
	echo "Atttempting to Force Play Sound on all lost units!!!!"
	#Now that we've reported lets go one step further
	#and play the annoying sound on anything that is lost
	UDID="$PlaySoundUDiDs"
	PlayLostSound
	echo " "
	echo " "

	#Work the Enabled Pile...
	echo "${Magenta}             Devices Currently WAITING TO GO TO LOST MODE${reset}"
	echo "${Blue}-----------************************************************-----------${reset}"
	cat /tmp/.pending2enable.lost_ish.txt | while read DataFromLostModeQuery; do
		#Fill variables based on data from file
		UDID2LookupLMQ=$(echo "$DataFromLostModeQuery" | cut -f 1 -d$'\t' )
		LASTBEATLMQ=$(echo "$DataFromLostModeQuery" |  cut -f 2 -d$'\t' )
		TAGSLMQ=$(echo "$DataFromLostModeQuery" | cut -f 3 -d$'\t')
		LOSTMODELMQ=$(echo "$DataFromLostModeQuery" |  cut -f 4 -d$'\t' )

		#Take Epoch time and convert to hours
		LASTCHECKINLMQ=$($PYTHON2USE -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTBEATLMQ")).strftime('%Y-%m-%d %I:%M:%S %p'))")

		#Now query our cache'd info to fill in the blanks.
		UDID2Lookup=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$UDID2LookupLMQ")

		if [ -z "$UDID2Lookup" ]; then
			log_line "ERROR: Device UDID not found in MOSBasic data!"
			break
		fi

		#Pass the info we just got to the parse routine.
		line="$UDID2Lookup"
		ParseIt_ios

		if [ -z "$USERID" ]; then
			USERID="NotAss"
			NAME="NOT ASSIGNED"
		fi

		if [ -z "$TAGSLMQ" ]; then
			TAGSLMQ="NO TAGS"
		fi

		#Figure out how many hours ago last beat was
		current_time=$(date +%s)
		current_time=$(expr "$current_time" / 3600 )
		before_time=$(expr "$LASTBEATLMQ" / 3600 )
		hoursagoLMQ=$(expr "$current_time" - "$before_time" )

		echo "$UDID2Lookup"
		# #Based on hours above color code our output.  Green is day or less, Yellow is 3
		# #days or less, and red is everything else.
		# if [ "$hoursagoLMQ" -lt 24 ]; then
		# 	echo "${Green}$ASSETTAG / $LASTCHECKINLMQ / $USERID / $NAME / $TAGSLMQ ${reset}"
		# elif [ "$hoursagoLMQ" -lt 72 ]; then
		# 	echo "${Yellow}$ASSETTAG/ $LASTCHECKINLMQ / $USERID / $NAME / $TAGSLMQ ${reset}"
		# else
		# 	echo "${Red}$ASSETTAG / $LASTCHECKINLMQ / $USERID / $NAME / $TAGSLMQ ${reset}"
		# fi

	done

	echo " "
	echo " "

}


#############################
#          Do Work          #
#############################
#Before we can do anything we need to make sure we have a Bearer Token
GetBearerToken

#First parse the Tag unless this is blanket whos lost query
if [ -z "$2" ] && [ ! "$1" = "--whoislost" ]; then
	cli_log "Need an asset tag to act on.  Come'on man!"
	exit 1

#Unless we are doing a blanket whos lost query we need to 
#get the serial # here.	
elif [ ! "$1" = "--whoislost" ]; then
	TAG_GIVEN="$2"
	SerialFromTag
fi

#Now take our argument and move forward.
if [ "$1" = "--sound" ]; then
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	PlayLostSound

elif [ "$1" = "--enable" ]; then
	CheckLostMode
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	
	EnableLostMode
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	
elif [ "$1" = "--disable" ]; then
	DisableLostMode
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	
elif [ "$1" = "--status" ]; then
	CheckLostMode	
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"		
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	
	DisplayCheckdLostModeData
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi
	
elif [ "$1" = "--whoislost" ]; then
	WHOISLOST
elif [ "$1" = "--LocateiPad" ]; then
	LocateDevice
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Content sent-> $content"
		echo "API OUTPUT-> $APIOUTPUT"
	fi	
else
	cli_log "Bad arguments given <$1/$2> Try again."
	exit 1
fi

