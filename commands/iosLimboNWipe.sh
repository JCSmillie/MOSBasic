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
	IsThisiPadSharedMode
	
	#if Shared we only want to wipe
	if [ "$ISSHARED" = "TRUE" ]; then
		
		cli_log "$ASSETTAG is a Shared iPad.  Will not Limbo first; ONLY WIPE"
	
		#if this is our first entry just fill the variable
		if [ -z "$WIPEUDiDs" ]; then
			WIPEUDiDs="$UDID"
		else
			#all others are additons to the variable
			WIPEUDiDs=$(echo "$WIPEUDiDs,$UDID")
		fi
		
		echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt
		
	else
		#Otherwise Wipe and Limbo.
		#if this is our first entry just fill the variable
		if [ -z "$LIMBOSetUDiDs" ]; then
			LIMBOSetUDiDs="$UDID"
		else
			#all others are additons to the variable
			LIMBOSetUDiDs=$(echo "$LIMBOSetUDiDs,$UDID")
		fi
		
		echo "$RETURNSERIAL" >> /tmp/Scand2WipeLimbo_Serialz.txt
	fi
}

#Format for an iPad Data Dump of JSON
Generate_JSON_BulkOperations() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"elements": [ {
        "operation": "$OPERATION2PERFORM",
    	"devices": "$DEVICES2BULKON"
	} ]
}
EOF
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
			SorterOfiPadz
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

echo "Proceeding to Wipe & Limbo the following:"
echo "------------------------------------------"	
#cat /tmp/Scand2WipeLimbo_Serialz.txt
echo "Limbo and Wipe UDIDs-> $LIMBOSetUDiDs"

echo "Proceeding to Wipe the following:"
echo "----------------------------------"
#cat /tmp/Scand2Wipe_Serialz.txt
echo "Just Wipe UDIDs-> $WIPEUDiDs"

#Has confirmation been given?  Get it
if [ -z "$shouldwedoit" ]; then
	echo "Are you sure <Y/N>"
	read shouldwedoit
fi


if [ "$shouldwedoit" = "Y" ] || [ "$shouldwedoit" = "y" ]; then

	#At this point we are almost ready to do the wipe and limbo
	if [ ! -z "$LIMBOSetUDiDs" ]; then
		
		#Before starting to grab data lets grab the Bearer Token
		GetBearerToken
		

		
		echo "Making it So #1."
		#This is a new CURL call with JSON data - JCS 11/8/23
		OPERATION2PERFORM="change_to_limbo"
		DEVICES2BULKON="$LIMBOSetUDiDs"
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations)"
		
		cli_log "Limbo commands sent against these devices: $DEVICES2BULKON"

		OPERATION2PERFORM="wipe_devices"
		DEVICES2BULKON="$LIMBOSetUDiDs"
		#This is a new CURL call with JSON data - JCS 11/8/23
		curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
		--header 'Content-Type: application/json' \
			--header "Authorization: Bearer $AuthToken" \
			--data "$(Generate_JSON_BulkOperations)"
		
		cli_log "Limbo commands sent against these devices: $DEVICES2BULKON"

	else
		#If we are here then we got nothing to work on
		echo "No UDIDs are in cache for Limbo and Wipe.  Doing Nothing."
	fi

	#At this point we are almost ready to do the wipe and limbo
	if [ ! -z "$WIPEUDiDs" ]; then
		
		#Before starting to grab data lets grab the Bearer Token
		GetBearerToken
		
			echo "Making it So #1."
			OPERATION2PERFORM="wipe_devices"
			DEVICES2BULKON="$WIPEUDiDs"
			#This is a new CURL call with JSON data - JCS 11/8/23
			curl --location 'https://managerapi.mosyle.com/v2/bulkops' \
			--header 'Content-Type: application/json' \
				--header "Authorization: Bearer $AuthToken" \
				--data "$(Generate_JSON_BulkOperations)"
			
			cli_log "Limbo commands sent against these devices: $DEVICES2BULKON"

	else
		echo "No UDIDs are in cache for Wipe Only.  Doing Nothing."
	fi
	
	#Check if this was an --uncache run and if so delete the cache file.
	if [ "$1" = "--uncache" ]; then
		echo "Cache purge option was run.  Will also delete the back cache file."
		rm -Rf /tmp/Scand2Wipe_CACHE_Serialz.txt
	fi

else
	echo "Its ok... we all get cold feet sometimes...."
	exit 1
fi
