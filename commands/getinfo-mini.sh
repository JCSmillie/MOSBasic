#!/bin/zsh
################################################################
#
#	getinfo-mini.sh  
#		Script takes input of serial, asset tag, or userid
#		and looks device up against known info.
#
#		JCS / 2025/04/02 --> Same as the info command just without
#		Colors and what not.
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

CMDRAN="GETINFO"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi




################################
#            DO WORK           #
################################
#Make sure we were given criteria to do a look up
if [ -z "$1" ]; then
	cli_log "No lookup point <ASSET TAG/SERIAL/USERID> given..  Can't do this."
	exit 1
fi

#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 3,6,8,9 | grep "$1")
#Strip FoundIt down to JUST THE SERIAL #
FoundItIOS=$(echo "$FoundItIOS" | cut -d$'\t' -f 1)
if [ "$MB_DEBUG" = "Y" ]; then
	echo "We Got a Hit (iPad)-> $FoundItIOS"
fi

#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
FoundItMACOS=$(cat "$TEMPOUTPUTFILE_MERGEDMAC" | cut -d$'\t' -f 3,6,8,9 | grep "$1")
#Strip FoundIt down to JUST THE SERIAL #
FoundItMACOS=$(echo "$FoundItMACOS" | cut -d$'\t' -f 1)
if [ "$MB_DEBUG" = "Y" ]; then
	echo "We Got a Hit (Mac)-> $FoundItMACOS"
fi

####THIS IS WHERE WE SEARCH FOR IPADS
if [ ! -z "$FoundItIOS" ]; then
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Tag Check-> $FoundItIOS"
	fi
	
	#Check to see how many results we got.
	WCC=$(echo "$FoundItIOS" | wc -l )
	WCC="${WCC//[[:space:]]/}"
	
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "WC=$WCC"
	fi
	
	#If we got more than 1 result lets use a loop to look
	#each one up.
	if [ "$WCC" -gt "1" ]; then
		echo "Search for $1 gave multiple results."

		echo "$FoundItIOS" | while read FoundOne; do

			FoundOne=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundOne")


			line="$FoundOne"
			ParseIt_ios
			#Attempt to get current infomation from MDM
			GetCurrentInfo-ios

			if [ -z "$ENROLLMENT_TYPE" ]; then
			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
			else
				echo "UDID=$UDID"
				echo "DeviceSerialNumber=$DeviceSerialNumber"
				echo "CURRENTNAME=$CURRENTNAME"
				echo "TAGS=$TAGS"
				echo "ASSET TAG=$ASSETTAG"
				echo "LASTCHECKIN=$LASTCHECKIN"
				echo "ENROLLMENT_TYPE=$ENROLLMENT_TYPE"
				echo "USERID=$USERID"
				echo "ASSIGNED TO=$NAME"
				echo "Lost Mode Status=$LOSTMODESTATUS"
				echo "Last WAN IP=$LAST_IP_BEAT"
				echo "Last LAN IP=$LAST_LAN_IP"							
			fi


		done

	else

		#Otherwise we got one device.  Just display with no loop call.
		FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundItIOS")
		line="$FoundItIOS"
		ParseIt_ios
		#Attempt to get current infomation from MDM
		GetCurrentInfo-ios

		if [ -z "$ENROLLMENT_TYPE" ]; then
			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
		else
			echo "UDID=$UDID"
			echo "DeviceSerialNumber=$DeviceSerialNumber"
			echo "CURRENTNAME=$CURRENTNAME"
			echo "TAGS=$TAGS"
			echo "ASSET TAG=$ASSETTAG"
			echo "LASTCHECKIN=$LASTCHECKIN"
			echo "ENROLLMENT_TYPE=$ENROLLMENT_TYPE"
			echo "USERID=$USERID"
			echo "ASSIGNED TO=$NAME"
			echo "Lost Mode Status=$LOSTMODESTATUS"
			echo "Last WAN IP=$LAST_IP_BEAT"
			echo "Last LAN IP=$LAST_LAN_IP"		

		fi
	fi
else
	cli_log "No hits for $1 in the iPad data.  Please double check your info and try again."
fi


###################
#If both results came back negative
if [ -z "$FoundItIOS" ] && [ -z "$FoundItMACOS" ]; then
	cli_log "No hits for $1.  Please double check your info and try again."
	exit 1
	
else
	exit 0
fi
