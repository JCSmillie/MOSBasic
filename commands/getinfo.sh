#!/bin/zsh

################################################################
#
#	getinfo.sh  
#		Script takes input of serial, asset tag, or userid
#		and looks device up against known info.
#
#		JCS - 9/28/2021  -v1
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="GetInfo"

echo "Variable 1-> $1"
echo "Variable 2-> $2"
echo "Variable 3-> $3"
echo "Variable 4-> $4"

################################
#            DO WORK           #
################################


#Make sure we were given criteria to do a look up
if [ -z "$1" ]; then
	cli_log "No lookup point <ASSET TAG/SERIAL/USERID> given..  Can't do this."
	exit 1
fi

#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
FoundIt=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 2-9 | grep "$1")
#Strip FoundIt down to JUST THE SERIAL #
FoundIt=$(echo "$FoundIt" | cut -d$'\t' -f 1)
echo "We Got a Hit-> $FoundIt"
if [ ! -z "$FoundIt" ]; then
	echo "Tag Check-> $FoundIt"

	#Check to see how many results we got.
	WCC=$(echo "$FoundIt" | wc -l )
	WCC="${WCC//[[:space:]]/}"
	echo "WC=$WCC"
	
	#If we got more than 1 result lets use a loop to look
	#each one up.
	if [ "$WCC" -gt "1" ]; then
		echo "Search for $1 gave multiple results."
		
		echo $FoundIt | while read FoundOne; do
			
			FoundOne=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundOne")
			
						
			line="$FoundOne"
			ParseIt_ios 

			if [ -z "$ENROLLMENT_TYPE" ]; then
			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
			else
				echo "${Red}--------------------------------------------------${reset}"
				echo "${Blue}UDID=${Green}$UDID${reset}"
				echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
				echo "${Blue}CURRENTNAME=${Green}$CURRENTNAME${reset}"
				echo "${Blue}TAGS=${Green}$TAGS${reset}"
				echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
				echo "${Blue}LASTCHECKIN=${Green}$LASTCHECKIN${reset}"
				echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
				echo "${Blue}USERID=${Green}$USERID${reset}"
				echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"
				echo "${Red}--------------------------------------------------${reset}"
			fi
			
			
		done
		
		exit 0
		
	else
		
		#Otherwise we got one device.  Just display with no loop call.
		FoundIt=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundIt")
		line="$FoundIt"
		ParseIt_ios 

		if [ -z "$ENROLLMENT_TYPE" ]; then
			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
		else
			echo "${Blue}UDID=${Green}$UDID${reset}"
			echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
			echo "${Blue}CURRENTNAME=${Green}$CURRENTNAME${reset}"
			echo "${Blue}TAGS=${Green}$TAGS${reset}"
			echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
			echo "${Blue}LASTCHECKIN=${Green}$LASTCHECKIN${reset}"
			echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
			echo "${Blue}USERID=${Green}$USERID${reset}"
			echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"

		fi
	fi


	
	#We had a good hit.  Stop.
	exit 0
fi

###################
# If we are here then we got no hits.
cli_log "No hits for $1.  Please double check your info and try again."
exit 1


