#!/bin/zsh
################################################################
#
#	getinfo.sh  
#		Script takes input of serial, asset tag, or userid
#		and looks device up against known info.
#
#		JCS - 9/28/2021  -v1
#		JCS - 5/23/2022  --Added code to lookup IP address and Last beat
#						info relatively real time or as up to date as MDM
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

GetCurrentInfo-ios(){
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"serial_numbers\":[\"$DeviceSerialNumber\"],\"specific_columns\":\"date_last_beat,lostmode_status,last_ip_beat,last_lan_ip\"}}"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices') >> $LOG
	
	if echo "$output" | grep "DEVICES_NOTFOUND"; then
		log_line "No updated info available for $DeviceSerialNumber"
		
	else
		if [ "$MB_DEBUG" = "Y" ]; then
			echo "$output" > "/tmp/$DeviceSerialNumber.GetCurrentInfo-ios.txt"
		fi
		
		MicroParse=$(echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"date_last_beat":"?(.*?)"?,"lostmode_status":"(.*?)","last_ip_beat":"?(.*?)"?,"last_lan_ip":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5/')

		LASTCHECKIN=$(echo "$MicroParse" |  cut -f 1 -d$'\t' )
		LOSTMODESTATUS=$(echo "$MicroParse" |  cut -f 2 -d$'\t' )
		LAST_IP_BEAT=$(echo "$MicroParse" |  cut -f 3 -d$'\t' )
		LAST_LAN_IP=$(echo "$MicroParse" |  cut -f 4 -d$'\t' )
		
		if [ "$LASTCHECKIN" = "null" ]; then
			LASTCHECKIN="NO-DATA"
		else
			#Take Epoch time and convert to hours
			LASTCHECKIN=$($PYTHON2USE -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTCHECKIN")).strftime('%Y-%m-%d %I:%M:%S %p'))")
		fi
		
		

	fi

}

GetCurrentInfo-macos(){
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"mac\",\"serial_numbers\":[\"$DeviceSerialNumber\"],\"specific_columns\":\"date_last_beat,lostmode_status,last_ip_beat,last_lan_ip\"}}"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices') >> $LOG
	
	if echo "$output" | grep "DEVICES_NOTFOUND"; then
		log_line "No updated info available for $DeviceSerialNumber"
		
	else
		if [ "$MB_DEBUG" = "Y" ]; then
			echo "$output" > "/tmp/$DeviceSerialNumber.GetCurrentInfo-macos.txt"
		fi
		
		MicroParse=$(echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"date_last_beat":"?(.*?)"?,"lostmode_status":"(.*?)","last_ip_beat":"?(.*?)"?,"last_lan_ip":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5/')

		LASTCHECKIN=$(echo "$MicroParse" |  cut -f 1 -d$'\t' )
		LOSTMODESTATUS=$(echo "$MicroParse" |  cut -f 2 -d$'\t' )
		LAST_IP_BEAT=$(echo "$MicroParse" |  cut -f 3 -d$'\t' )
		LAST_LAN_IP=$(echo "$MicroParse" |  cut -f 4 -d$'\t' )
		
		if [ "$LASTCHECKIN" = "null" ]; then
			LASTCHECKIN="NO-DATA"
		else
			#Take Epoch time and convert to hours
			LASTCHECKIN=$($PYTHON2USE -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LASTCHECKIN")).strftime('%Y-%m-%d %I:%M:%S %p'))")
		fi
		
		

	fi

}

################################
#            DO WORK           #
################################


#Make sure we were given criteria to do a look up
if [ -z "$1" ]; then
	cli_log "No lookup point <ASSET TAG/SERIAL/USERID> given..  Can't do this."
	exit 1
fi

#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 2-5,7-9 | grep "$1")
#Strip FoundIt down to JUST THE SERIAL #
FoundItIOS=$(echo "$FoundItIOS" | cut -d$'\t' -f 1)
if [ "$MB_DEBUG" = "Y" ]; then
	echo "We Got a Hit (iPad)-> $FoundItIOS"
fi

#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
FoundItMACOS=$(cat "$TEMPOUTPUTFILE_MERGEDMAC" | cut -d$'\t' -f 2,4-5,7-9 | grep "$1")
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
	
	#Throw up a banner for the iPads section
	echo "${Red}--------------------------------------------------${reset}"
	echo "${Red}|==               ${Yellow}iPads/iPhones${Red}                ==|${reset}"
	echo "${Red}--------------------------------------------------${reset}"

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
				echo "${Blue}Lost Mode Status=${Green}$LOSTMODESTATUS${reset}"
				echo "${Blue}Last WAN IP=${Green}$LAST_IP_BEAT${reset}"
				echo "${Blue}Last LAN IP=${Green}$LAST_LAN_IP${reset}"				
				
				echo "${Red}--------------------------------------------------${reset}"
				
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
			echo "${Blue}UDID=${Green}$UDID${reset}"
			echo "${Blue}DeviceSerialNumber=${Green}$DeviceSerialNumber${reset}"
			echo "${Blue}CURRENTNAME=${Green}$CURRENTNAME${reset}"
			echo "${Blue}TAGS=${Green}$TAGS${reset}"
			echo "${Blue}ASSET TAG=${Green}$ASSETTAG${reset}"
			echo "${Blue}LASTCHECKIN=${Green}$LASTCHECKIN${reset}"
			echo "${Blue}ENROLLMENT_TYPE=${Green}$ENROLLMENT_TYPE${reset}"
			echo "${Blue}USERID=${Green}$USERID${reset}"
			echo "${Blue}ASSIGNED TO=${Green}$NAME${reset}"
			echo "${Blue}Lost Mode Status=${Green}$LOSTMODESTATUS${reset}"
			echo "${Blue}Last WAN IP=${Green}$LAST_IP_BEAT${reset}"
			echo "${Blue}Last LAN IP=${Green}$LAST_LAN_IP${reset}"	

		fi
	fi
else
	cli_log "No hits for $1 in the iPad data.  Please double check your info and try again."
fi

####THIS IS WHERE WE SEARCH FOR MACS
if [ ! -z "$FoundItMACOS" ]; then
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "Tag Check-> $FoundItMACOS"
	fi
	
	#Throw up a banner for the Mac section
	echo "${Red}--------------------------------------------------${reset}"
	echo "${Red}|==                    ${Yellow}Macs${Red}                    ==|${reset}"
	echo "${Red}--------------------------------------------------${reset}"

	#Check to see how many results we got.
	WCC=$(echo "$FoundItMACOS" | wc -l )
	WCC="${WCC//[[:space:]]/}"
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "WC=$WCC"
	fi

	#If we got more than 1 result lets use a loop to look
	#each one up.
	if [ "$WCC" -gt "1" ]; then
		echo "Search for $1 gave multiple results."

		echo "$FoundItMACOS" | while read FoundOne; do

			FoundOne=$(cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "$FoundOne")


			line="$FoundOne"
			ParseIt_MacOS	
			#Attempt to get current infomation from MDM
			GetCurrentInfo-macos	

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
				echo "${Blue}Lost Mode Status=${Green}$LOSTMODESTATUS${reset}"
				echo "${Blue}Last WAN IP=${Green}$LAST_IP_BEAT${reset}"
				echo "${Blue}Last LAN IP=${Green}$LAST_LAN_IP${reset}"				
				echo "${Red}--------------------------------------------------${reset}"
			fi


		done

	else

		#Otherwise we got one device.  Just display with no loop call.
		FoundItMACOS=$(cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "$FoundItMACOS")
		line="$FoundItMACOS"
		ParseIt_MacOS
		#Attempt to get current infomation from MDM
		GetCurrentInfo-macos

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
			echo "${Blue}Lost Mode Status=${Green}$LOSTMODESTATUS${reset}"
			echo "${Blue}Last WAN IP=${Green}$LAST_IP_BEAT${reset}"
			echo "${Blue}Last LAN IP=${Green}$LAST_LAN_IP${reset}"			

		fi
	fi
fi

###################
#If both results came back negative
if [ -z "$FoundItIOS" ] && [ -z "$FoundItMACOS" ]; then
	cli_log "No hits for $1.  Please double check your info and try again."
	exit 1
	
else
	exit 0
fi

