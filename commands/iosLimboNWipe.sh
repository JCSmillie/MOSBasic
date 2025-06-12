#!/bin/zsh

################################################################
#
#	iosLimboNWipe.sh  
#		Script takes input of asset tag, looks up serial, then
#		tells Mosyle to Limbo the device and wipe the device.
#
#		JCS - 9/30/2021  -v1
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="iOSLimboNWipe"

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
	
	if [ ! -z "$2" ]; then
		RETURNSERIAL="$2"
		DeviceSerialNumber="$RETURNSERIAL"
	fi
	
	if [ "$RETURNSERIAL" = "TOOMANYSERIALS" ]; then
		cli_log "LOCAL-> $TAG_GIVEN cannot be found.  Skipping!"
		
		if [ -z "$SharediPadsProcessed" ]; then
			FailediPads="$TAG_GIVEN"
		else
			#all others are additons to the variable
			FailediPads=$(echo "$FailediPads,$TAG_GIVEN")
		fi
		
	else
		IsThisiPadSharedMode 
		
		#if Shared we only want to wipe
		if [ "$ISSHARED" = "TRUE" ]; then
		
			cli_log "$TAG_GIVEN is a Shared iPad.  Will not Limbo first; ONLY WIPE"
			
			if [ -z "$SharediPadsProcessed" ]; then
				SharediPadsProcessed="$TAG_GIVEN"
			else
				#all others are additons to the variable
				SharediPadsProcessed=$(echo "$SharediPadsProcessed,$TAG_GIVEN")
			fi
	
			# #if this is our first entry just fill the variable
			# if [ -z "$WIPEUDiDs" ]; then
			# 	WIPEUDiDs="$UDID"
			# else
			# 	#all others are additons to the variable
			# 	WIPEUDiDs=$(echo "$WIPEUDiDs,$UDID")
			# fi
			#
			# echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt
		
		else
			#Otherwise Wipe and Limbo.
			#if this is our first entry just fill the variable
			if [ -z "$LIMBOSetUDiDs" ]; then
				LIMBOSetUDiDs="$UDID"
			else
				#all others are additons to the variable
				LIMBOSetUDiDs=$(echo "$LIMBOSetUDiDs,$UDID")
			fi
		
			if [ -z "$LIMBOTagsWeWillProcess" ]; then
				LIMBOTagsWeWillProcess="$TAG_GIVEN"
			else
				#all others are additons to the variable
				LIMBOTagsWeWillProcess=$(echo "$LIMBOTagsWeWillProcess,$TAG_GIVEN")
			fi

			echo "$TODAY - Wipe & Limbo (RTS-> $RTS_ENABLED) - $TAG_GIVEN" >> "$LOCALCONF/MOSBasic/Scand2WipeLimbo_ProcessingLog.txt"

			echo "$RETURNSERIAL" >> /tmp/Scand2WipeLimbo_Serialz.txt
		
			echo "$RETURNSERIAL" >> $LOCALCONF/MOSBasic/InvUpdate.txt
		
		fi
		
		#ALL DEVICES GOING THROUGH SHOULD GET WIPED.
		#if this is our first entry just fill the variable
		if [ -z "$WIPEUDiDs" ]; then
			WIPEUDiDs="$UDID"
		else
			#all others are additons to the variable
			WIPEUDiDs=$(echo "$WIPEUDiDs,$UDID")
		fi
	
	
		if [ -z "$TAGSofWhatWillBeWiped" ]; then
			TAGSofWhatWillBeWiped="$TAG_GIVEN"
		else
			#all others are additons to the variable
			TAGSofWhatWillBeWiped=$(echo "$TAGSofWhatWillBeWiped,$TAG_GIVEN")
		fi
	
	
		echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt
		
	fi
}

#Format for an iPad Data Dump of JSON
Generate_JSON_BulkOperations() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "$OPERATION2PERFORM",
    	"devices": [
		"$DEVICES2BULKON"
		]
	} ]
}
EOF
}

#Alternative JSON Bulk operation that uses Return to Service Mode.
#RTS ENABLED
Generate_JSON_BulkOperations_ALT() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "$OPERATION2PERFORM",
    	"devices": [
			"$DEVICES2BULKON"
			],
		"options": {
			"EnableReturnToService": "true",
			"DisallowProximitySetup": "true",
			"RevokeVPPLicenses": "true"
		}	
	} ]
}
EOF
}

#RTS DISABLED
Generate_JSON_BulkOperations_ALTNoRTS() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "$OPERATION2PERFORM",
    	"devices": [
			"$DEVICES2BULKON"
			],
		"options": {
			"DisallowProximitySetup": "true",
			"RevokeVPPLicenses": "true"
		}	
	} ]
}
EOF
}

CalliPadWipeRoutine() {
	#DEBUGGING
	if [ "$MB_DEBUG" = "Y" ]; then
			echo "******----DEBUG----*****--> RTS_ENABLED equals ($RTS_ENABLED)"
			echo "******----DEBUG----*****--> Operation being performed-> ($OPERATION2PERFORM)"
			echo "******----DEBUG----*****--> Devices acting on:"
			echo "******----DEBUG----*****--> ($DEVICES2BULKON)"
	fi

	#Before starting to grab data lets grab the Bearer Token
	GetBearerToken
	
	if [ "$RTS_ENABLED" = Y ]; then
		echo "Making it So #1 - UTILIZING RTS."
		#This is a new CURL call with JSON data - JCS 11/8/23
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations_ALT)" >> $LOG
		
		#echo "$Generate_JSON_BulkOperations_ALT"
		if [ "$MB_DEBUG" = "Y" ]; then
				echo "******----DEBUG----*****--> iPad Wipe Routine:"
				echo "$Generate_JSON_BulkOperations_ALT"
				echo "******----/DEBUG---*****"
		fi
		
		cli_log "Wipe w/RTS commands sent against these devices: $TAGSofWhatWillBeWiped"
		
	else
		echo "Making it So #1 - Not Utilizing RTS."
		#This is a new CURL call with JSON data - JCS 11/8/23
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations_ALTNoRTS)" >> $LOG
		
		#echo "$Generate_JSON_BulkOperations_ALT"
		if [ "$MB_DEBUG" = "Y" ]; then
				echo "******----DEBUG----*****--> iPad Wipe Routine:"
				echo "$Generate_JSON_BulkOperations_ALTNoRTS"
				echo "******----/DEBUG---*****"
		fi
		
		cli_log "Wipe w/o RTS commands sent against these devices: $TAGSofWhatWillBeWiped"		
	fi
		
	
}

#############################
#          Do Work          #
#############################
#This would be a routine for doing Scan and Go based on $1 equaling --scan
if [ "$1" = "--scan" ]; then

	#prompt User to scan.
	echo "${Green}Please scan an asset tag.  When you've scanned"
	echo "them all just press ENTER to give me a blank${reset}"
	
	#Do a loop and keep taking scan data until we get null
	while true; do
		
		echo "Asset tag of device?"
		read scannedin
		echo "$scannedin" >> /tmp/Scand2Wipe.txt
		
		if [ -z "$scannedin" ]; then
			echo "${Green} Last code scanned.  Proceeding."
			break
		fi
	done
	
	cat "/tmp/Scand2Wipe.txt" | while read TAG_GIVEN; do
		
		echo "DEBUG-> This is where we lookup $TAG_GIVEN"
		
		if [ -z "$TAG_GIVEN" ]; then
			echo "DEBUG-> Blank tag <$TAG_GIVEN> scanned.  Skipping."
			break
		fi
		
		SerialFromTag

		if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
			echo "${Red}Cant find $TAG_GIVEN in cached Mosyle data.  EPIC FAIL${reset}"
			echo "${Red}Skipping $TAG_GIVEN.  EPIC FAIL${reset}"
		else
			echo "Asset tag $TAG_GIVEN is $RETURNSERIAL"
			
			#Call Sorter function to seperate out the Shared iPads from regular iPads
			#before we act.  Shared iPads should NEVER be limbo'd before wiping.
			SorterOfiPadz "$RETURNSERIAL"
		fi
	done
		

#This would be a routine for doing a bunch of devices from file based on $1 equaling --mass
# and $2 equaling where to find a file.  File would be asset tag per line.
elif [ "$1" = "--mass" ]; then
		echo "MASS ABILITY IS NOT YET READY..  Fail.. for now."

#This command is meant to be called by a another script so it can utilize
#MOSBasic to handle the needs of "unassigning" an iPad.
elif [ "$1" = "--cache" ]; then
	TAG_GIVEN="$2"

	SerialFromTag	
	
	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
		
		HOWMANY=$(wc -l < /tmp/Scand2Wipe_CACHE_Serialz.txt)
		if [ "$HOWMANY" -gt "0" ]; then
			echo "There are $HOWMANY serials waiting in cache to be processed."
		fi
		
		
		exit 1
	
	else
		echo "Asset tag $TAG_GIVEN is $RETURNSERIAL.    Cache'ng for later..."
		echo "$RETURNSERIAL,$UDID" >> /tmp/Scand2Wipe_CACHE_Serialz.txt
		
		HOWMANY=$(wc -l < /tmp/Scand2Wipe_CACHE_Serialz.txt)
		HOWMANY="${HOWMANY//[[:space:]]/}"
		if [ "$HOWMANY" -gt "0" ]; then
			echo "There are $HOWMANY serials waiting in cache to be processed."
		fi
		
		exit 0
	fi
		
#This funcion is to purge the Cache we previously created and bulk run commands.		
elif [ "$1" = "--uncache" ]; then

	HOWMANY=$(wc -l < /tmp/Scand2Wipe_CACHE_Serialz.txt)
	HOWMANY="${HOWMANY//[[:space:]]/}"
	
	if [ "$HOWMANY" -lt "1" ]; then
		echo "Cache has no data.  ($HOWMANY) will not proceed."
		exit 1
		
	else
		
		for TAG_GIVEN in `cat /tmp/Scand2Wipe_CACHE_Serialz.txt`; do
			
			
			echo "Looking up $TAG_GIVEN"
			
			RETURNSERIAL=$(echo "$TAG_GIVEN" | cut -d ',' -f 1)
			UDID=$(echo "$TAG_GIVEN" | cut -d ',' -f 2)
			
			echo "Working with $RETURNSERIAL ($UDID)"
						
			#Call Sorter function to seperate out the Shared iPads from regular iPads
			#before we act.  Shared iPads should NEVER be limbo'd before wiping.
			SorterOfiPadz
			
		done
	fi
		
elif [ "$1" = "--norts" ]; then
	TAG_GIVEN="$2"
	RTS_ENABLED="N"

	SerialFromTag	
	
	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
		
		HOWMANY=$(wc -l < /tmp/Scand2Wipe_CACHE_Serialz.txt)
		if [ "$HOWMANY" -gt "0" ]; then
			echo "There are $HOWMANY serials waiting in cache to be processed."
		fi
		
		
		exit 1
	
	else
		echo "Asset tag $TAG_GIVEN is $RETURNSERIAL.    Cache'ng for later..."
		echo "$RETURNSERIAL,$UDID" >> /tmp/Scand2Wipe_CACHE_Serialz.txt
		
		#Call Sorter function to seperate out the Shared iPads from regular iPads
		#before we act.  Shared iPads should NEVER be limbo'd before wiping.
		SorterOfiPadz

		#IF we are sending a single ASSET Tag just do it.  Otherwise
		#seek confirmation.
		shouldwedoit="Y"
	fi
			


#This Routine is for doing a single asset tag.
#Pull all serials from file and parse to get UDiD numbers.
else 
	TAG_GIVEN="$1"

	SerialFromTag

	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
	
	else
		echo "Asset tag $TAG_GIVEN is $RETURNSERIAL."
		echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt		
		
		#Call Sorter function to seperate out the Shared iPads from regular iPads
		#before we act.  Shared iPads should NEVER be limbo'd before wiping.
		SorterOfiPadz

		#IF we are sending a single ASSET Tag just do it.  Otherwise
		#seek confirmation.
		shouldwedoit="Y"
	fi
fi

#Check to see if we should use Return to Service Mode
if [ -z "$RTS_ENABLED" ]; then
	echo " "
	echo "ATTENTION!!!!!"
	echo " **MOSBASIC SUPPORTS Return to Service Mode (RTS)"
	echo "-------------------------------------------------"
	echo "Wipe with Return to Service mode? <Y/N>"
	echo "-------------------------------------------------"
	read RTS_ENABLED
	
	echo "RTS_ENABLED ---> $RTS_ENABLED"
	
	# if [ ! "$RTS_ENABLED" = N ] || [ ! "$RTS_ENABLED" = n ]; then
	# 	RTS_ENABLED="Y"
	#
	# fi
	
	cli_log "RTS MODE Enabled set to ($RTS_ENABLED)"
fi


echo "RTS_ENABLED ---> $RTS_ENABLED"


echo "Following Devices will be set to Limbo:"
echo "------------------------------------------"	
#cat /tmp/Scand2WipeLimbo_Serialz.txt
echo "$LIMBOTagsWeWillProcess"

echo "Proceeding to Wipe the following:"
echo "----------------------------------"
#cat /tmp/Scand2Wipe_Serialz.txt
echo "$TAGSofWhatWillBeWiped"

#Point out any iPAds that failed.
if [ ! -z "$FailediPads" ]; then
	echo "The Following devices FAILED to lookup:"
	echo "-----------------------------------------"
	echo "$FailediPads"
fi
	
#Just some spacing drops to make things line up better	
echo " "
echo " "


#Has confirmation been given?  Get it
if [ -z "$shouldwedoit" ]; then
	echo "Are you sure <Y/N>"
	read shouldwedoit
fi

#Has confirmation been given?  Get it
if [ -z "$shouldwedoit" ]; then
	echo "Are you sure <Y/N>"
	read shouldwedoit
fi

if [ "$shouldwedoit" = "Y" ] || [ "$shouldwedoit" = "y" ]; then
	
	###SEND DEVICES TO LIMBO
	#At this point we are almost ready to do the wipe and limbo
	if [ ! -z "$LIMBOSetUDiDs" ]; then
		
		#Before starting to grab data lets grab the Bearer Token
		GetBearerToken
		
		# #Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd'
		OPERATION2PERFORM="clear_commands"
		DEVICES2BULKON="$LIMBOSetUDiDs"
		
		cli_log "Sending back command clear to LIMBOTagsWeWillProcess"
		#This is a new CURL call with JSON data - JCS 11/8/23
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations)" >> $LOG

		
		#echo "Making it So #1."
		cli_log "Changing Device State to Limbo for LIMBOTagsWeWillProcess"
		#This is a new CURL call with JSON data - JCS 11/8/23
		OPERATION2PERFORM="change_to_limbo"
		DEVICES2BULKON="$LIMBOSetUDiDs"
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations)" >> $LOG

		#echo "Making it So #1."
		cli_log "Removing lost mode from LIMBOTagsWeWillProcess"
		#This function comes from lostmodefun.sh
		DisableLostModeBULK  

		
		# cli_log "Sending Wipe Commands to $DEVICES2BULKON"
		#
		# #Set Variables
		# OPERATION2PERFORM="wipe_devices"
		# DEVICES2BULKON="$LIMBOSetUDiDs"
		# CalliPadWipeRoutine
		


	else
		#If we are here then we got nothing to work on
		echo "No UDIDs are in cache for Limbo and Wipe.  Doing Nothing."
	fi


	cli_log "Sending Wipe Commands to $LIMBOTagsWeWillProcess"

	#Set Variables
	OPERATION2PERFORM="wipe_devices"
	DEVICES2BULKON="$WIPEUDiDs"
	CalliPadWipeRoutine
	
	#Check if this was an --uncache run and if so delete the cache file.
	if [ "$1" = "--uncache" ]; then
		echo "Cache purge option was run.  Will also delete the back cache file."
		rm -Rf /tmp/Scand2Wipe_CACHE_Serialz.txt
	fi
	
	#If we had shared iPads point them out here.
	if [ ! -z "$SharediPadsProcessed" ]; then
		cli_log "Shared Mode Devices (Not Limbo'd pre wipe)--> $SharediPadsProcessed"
	fi
	
	#Give the list of devices we wiped.
	cli_log "Devices Wiped--> $LIMBOTagsWeWillProcess"
	
	#Point out any iPAds that failed.
	if [ ! -z "$FailediPads" ]; then
		cli_log "FAILED DEVICES-> $FailediPads"
	fi

else
	echo "Its ok... we all get cold feet sometimes...."
	exit 1
fi
