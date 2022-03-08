#!/bin/zsh

################################################################
#
#	groupsquery.sh  
#		Script takes input of serial, asset tag, or userid
#		and looks device up against known info.
#
#		JCS - 2/5/2022  -v1
#
################################################################

BAGCLI_WORKDIR=/Users/jsmillie/GitHub/MOSBasic
TEMPOUTPUTFILE=/tmp/groups.txt

source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

CMDRAN="GROUPQUERY"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

################################
#            DO WORK           #
################################
listgroupsios() {
	THECOUNT=0
	while true; do
		let "THECOUNT=$THECOUNT+1"
		THEPAGE="$THECOUNT"
		content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"page\":$THEPAGE}}"
		output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevicegroups') >> $LOG
	
		#Detect we just loaded a page with no content and stop.
		LASTPAGE=$(echo $output | grep '"groups":\[\]')
		if [ -n "$LASTPAGE" ]; then
			let "THECOUNT=$THECOUNT-1"
			log_line "Yo we are at the end of the list (Last good page was $THECOUNT)"
			break
		fi

		echo " "
		echo "Page $THEPAGE data."
		echo "-----------------------"
		echo "$output"
		echo "----------------------"
	
		#Now take the JSON data we received and parse it into tab
		#delimited output.
		echo "$output" | awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"id":"(.*?)","name":"?(.*)","device_numbers":"?(.*)",*.*/\1\t\2\t\3\t\4/' | cut -d '}' -f 1 >> "$TEMPOUTPUTFILE"
	done
	
	cat "$TEMPOUTPUTFILE" | while read DataFromGroupQuery; do
		line="$DataFromGroupQuery"
		ParseIt_group
		echo "$GRPID / $GRPNAME / $GRPNUMOFMEMBS"
	done
}

listgroupsmacos() {
	THECOUNT=0	
	while true; do
		let "THECOUNT=$THECOUNT+1"
		THEPAGE="$THECOUNT"
		content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"mac\",\"page\":$THEPAGE}}"
		output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevicegroups') >> $LOG
	
		#Detect we just loaded a page with no content and stop.
		LASTPAGE=$(echo $output | grep '"groups":\[\]')
		if [ -n "$LASTPAGE" ]; then
			let "THECOUNT=$THECOUNT-1"
			log_line "Yo we are at the end of the list (Last good page was $THECOUNT)"
			break
		fi

		echo " "
		echo "Page $THEPAGE data."
		echo "-----------------------"
		echo "$output"
		echo "----------------------"
	
		#Now take the JSON data we received and parse it into tab
		#delimited output.
		echo "$output" | awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"id":"(.*?)","name":"?(.*)","device_numbers":"?(.*)",*.*/\1\t\2\t\3\t\4/' | cut -d '}' -f 1 >> "$TEMPOUTPUTFILE"
	done
	
	cat "$TEMPOUTPUTFILE" | while read DataFromGroupQuery; do
		line="$DataFromGroupQuery"
		ParseIt_group
		echo "$GRPID / $GRPNAME / $GRPNUMOFMEMBS"
	done
}


# #Make sure we were given criteria to do a look up
# if [ -z "$1" ]; then
# 	cli_log "No lookup point <ASSET TAG/SERIAL/USERID> given..  Can't do this."
# 	exit 1
# fi
#
# #Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
# FoundIt=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 2-5,7-9 | grep "$1")
# #Strip FoundIt down to JUST THE SERIAL #
# FoundIt=$(echo "$FoundIt" | cut -d$'\t' -f 1)
# echo "We Got a Hit-> $FoundIt"
# if [ ! -z "$FoundIt" ]; then
# 	echo "Tag Check-> $FoundIt"
#
# 	#Check to see how many results we got.
# 	WCC=$(echo "$FoundIt" | wc -l )
# 	WCC="${WCC//[[:space:]]/}"
# 	echo "WC=$WCC"
#
# 	#If we got more than 1 result lets use a loop to look
# 	#each one up.
# 	if [ "$WCC" -gt "1" ]; then
# 		echo "Search for $1 gave multiple results."
#
# 		echo $FoundIt | while read FoundOne; do
#
# 			FoundOne=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundOne")
#
#
# 			line="$FoundOne"
# 			ParseIt_ios
#
# 			if [ -z "$ENROLLMENT_TYPE" ]; then
# 			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
# 			else
# 				echo "${Red}--------------------------------------------------${reset}"
# 				echo "${Blue}UDID=${Green}$UDID${reset}"
# 				echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
# 				echo "${Blue}CURRENTNAME=${Green}$CURRENTNAME${reset}"
# 				echo "${Blue}TAGS=${Green}$TAGS${reset}"
# 				echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
# 				echo "${Blue}LASTCHECKIN=${Green}$LASTCHECKIN${reset}"
# 				echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
# 				echo "${Blue}USERID=${Green}$USERID${reset}"
# 				echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"
# 				echo "${Red}--------------------------------------------------${reset}"
# 			fi
#
#
# 		done
#
# 		exit 0
#
# 	else
#
# 		#Otherwise we got one device.  Just display with no loop call.
# 		FoundIt=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$FoundIt")
# 		line="$FoundIt"
# 		ParseIt_ios
#
# 		if [ -z "$ENROLLMENT_TYPE" ]; then
# 			cli_log "$1 <$ASSETTAG/$DeviceSerialNumber> Is in Limbo or Shared Mode."
# 		else
# 			echo "${Blue}UDID=${Green}$UDID${reset}"
# 			echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
# 			echo "${Blue}CURRENTNAME=${Green}$CURRENTNAME${reset}"
# 			echo "${Blue}TAGS=${Green}$TAGS${reset}"
# 			echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
# 			echo "${Blue}LASTCHECKIN=${Green}$LASTCHECKIN${reset}"
# 			echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
# 			echo "${Blue}USERID=${Green}$USERID${reset}"
# 			echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"
#
# 		fi
# 	fi
#
#
#
# 	#We had a good hit.  Stop.
# 	exit 0
# fi
#
# ###################
# # If we are here then we got no hits.
# cli_log "No hits for $1.  Please double check your info and try again."
# exit 1
#


#############################
#          Do Work          #
#############################
#Clear the temp file
rm -Rf $TEMPOUTPUTFILE
#First parse the Tag unless this is blanket whos lost query
if [ -z "$1" ]; then
	cli_log "So what do you want me to do here?  Come'on man!"
	exit 1
fi


#Now take our argument and move forward.
if [ "$1" = "--mac" ]; then
	listgroupsmacos

elif [ "$1" = "--ios" ]; then
	listgroupsios

else
	cli_log "Bad arguments given <$1> .  This command only takes --ios and --mac.  Try again."
	exit 1
fi
