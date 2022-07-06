#!/bin/zsh
#
# ShakeNBake.sh
###################
# Utilize cfgutil and leverage Mosyle MDM Api to mass process
# ipads.  Process also relies on MOSBasic for some data files
# as well as configurations.  -- JCS Summer 22'
############
#
###PROFILE TO BE USED ON LOANER DEVICES - This has to be a wifi profile which cna get on to 
###a provisioning network.  If your not doing Shared iPads this can be ignored.
LOANERWIFIPROFILE="/Users/Shared/ShakeNBake/Profiles/GSD-Loaner-Wifi.mobileconfig"
###PROFILE TO BE USED ON LIMBO DEVICES - This has to be a wifi profile which cna get on to 
###a provisioning network.
LIMBOWIFIPROFILE="/Users/Shared/ShakeNBake/Profiles/AppleStoreWifi7Days.mobileconfig"

#Location for log output
LOGLOCATION="/Users/Shared/ShakeNBake/Logs"
#Location for Markerfile storage.  These are files SNB creates
#along the way to keep track of where it is at in the process.
TMPLOCATION="/Users/Shared/ShakeNBake/MarkerFilez"
#This option is for use with LoanerMonitor.sh... for the public
#version it should be ignored.
EXTRACFGS="/Users/Shared/ShakeNBake/Configz"

#This file is for local options like enable debug and setting prep Mode
#	DEBUG="Y"				<--Enable Debug
#	DEPLOYMODE="LOANER"		<-Set Deploy mode to Loaner.  Options are LOANER/WIPEONLY
#
#With no file or arguments we assume debug no and Deploymode is standard wipe, temp wifi profile, and DEP finish.
#
#		No Argument goes through DEP setup and uses regular wifi profile
#
#	Loaner profile should be for our network that is everywhere.  We don't want
#	students to login to our primary network as themselves for simplicity.
#
#	Regular wifi profile would be for a network that only exists 


#Options above (DEBUG / DEPLOYMODE ) can also be kept in a local file so that
#updates to this script can be done without worry of loosing changes.
#
# NOTE-> IF DEBUG IS ENABLED IN MOSBasic it will also be enabled here.
if [ -f "$EXTRACFGS/localcfgs.txt" ]; then
	source "$EXTRACFGS/localcfgs.txt"
fi

GENERALLOG="$LOGLOCATION/ShakeNBake.log"


BAGCLI_WORKDIR=$(readlink /usr/local/bin/mosbasic)
#Remove our command name from the output above
BAGCLI_WORKDIR=${BAGCLI_WORKDIR//mosbasic/}

#Make sure we have a location on MOSBasic commands.
if [ -z "$BAGCLI_WORKDIR" ]; then
	echo "You don't appear to have MOSBasic fully installed.  FAIL"
	exit 1
fi


export BAGCLI_WORKDIR
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"


################################
#          FUNCTIONS           #
################################
log_line() {
        LINE=$1
        TODAY=`date '+%a %x %X'`
        
		if [ "$DEBUG" = "Y" ]; then
			#Print on stdout
	        echo "$TODAY =====>$LINE"
			echo "$ECID / $UDID / $buildVersion / $locationID"
		fi			
		
        #Log to file
        echo "ShakeNBake_V2.sh ++> $TODAY =====> $LINE" >> "$GENERALLOG"
		
		#If we have an ECID at this point also put data
		#into seperate log.
		if [ ! -z "$UDID" ]; then
        	echo "ShakeNBake_V2.sh ++> $TODAY =====> $LINE" >> "$LOGLOCATION/CFGUTIL_LOG_$UDID.txt"
		fi
}

###I DONT THINK WE USE THIS.
# IIQ_GetAssetTag() {
# 	#Ask InicdentIQ what a Devices tag is.
# 	Query="$baseurl/assets/serial/$DeviceSERIAL"
# 	ASSETTAG=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep "AssetTag" | cut -d ':' -f 2 | cut -d ',' -f 1 | head -1 | tr -d \")
# }



#STEP 1-> Erase or Restore iPad
RestoreDevice() {
	#Get Booted State of device.  Erase only works if its booted.  If its not booted
	#dont wase our time trying.
	GetDeviceState=$(/usr/local/bin/cfgutil --ecid "$ECID" get bootedState isPaired 2>/dev/null )
	Devicebootstate=$(echo "$GetDeviceState" | grep -a1 bootedState: | tail -1)
	Devicepairingstate=$(echo "$GetDeviceState" | grep -a1 isPaired: | tail -1)
	
	#If device is booted (IE NOT DFU OR FAC RESTORE) and WE CAN PAIR THEN TRY TO ERASE.
	#Without trust you cant pair.  Without pairing you can't erase so if no dont even try.		
	if [ "$Devicebootstate" = "Booted" ]; then
		if  [ "$Devicepairingstate" = "yes" ]; then
			####THIS WOULD BE A GOOD PLACE TO CHECK FIRMWARE VERSION BEFORE ERASING.  If
			####FW is out of date why erase just to have to RESTORE after?  
			HayLookAtMe "We appear to have AC2 TRUST - ATTEMPTING ERASE"
			#Try to Erase First
			DoIT=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" erase"  2>/dev/null )
			

			if [ "$?" = "1" ]; then
				log_line "ERASE: Epic Fail on $ECID / $UDID.    Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
				HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				exit 1

			else
				log_line "ERASE Success ($UDID) - Next Steps will happen when iPad boots back up."
				HayLookAtMe "TRUST ERASE successful!"
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "Take a breath...  Waiting a few before moving on so iPad can catch up."
				sleep 60
				#exit 1

			fi
		else
			#If we are here its because the iPad is Booted, but not paired.
			log_line "RESTORE: $ECID / ($UDID) appears to be in a booted but not paired. ($Devicebootstate / $Devicepairingstate)."
			HayLookAtMe "No AC2 TRUST.  Trying Mosyle wipe."
			#Attempt to do an OTA wipe.  If iPad has checked into Mosyle in less than 12 hrs its a fair chance it works
			#out...
			WipeOTAMosyle
		fi
		
	elif  [ "$Devicebootstate" = "Recovery" ]; then
		HayLookAtMe "iPad is in DFU Mode...."
		log_line "RESTORE: $ECID / ($UDID) device in DFU mode.  Jumping right to restore attempt."
		FullPressWipe=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" restore"  2>/dev/null )

		if [ "$?" = "1" ]; then
			log_line "RESTORE: Epic Fail on $ECID / ($UDID).  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
			exit 1

		else
			log_line "RESTORE Success ($UDID) - Next Steps will happen when iPad boots back up."
			HayLookAtMe "Restore SUCCESS."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			exit 0
		fi
		
	else
		log_line "RESTORE: Epic Fail on $ECID.  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
		exit 1
		
	fi
}

CheckBuildVersion() {
	#This chunk of code is all new.  Back in April 22' an AppleSE inquired about how do I know a device needs
	#updated or note.  Originally I had a manual table listed of build numbers.  This table had to be updated
	#every time a new version comes out though.  Instead now we ask Apple for a list of all device types and
	#what version of iPadOS they should have.  Ask the iPad what firmware it has, compare, and act.  
	
	#Make sure we have a data file from Apple about currently available iOS/iPadOS versions.
	#NOTE-> This function comes from MOSBasic/Common
	GetAppleUpdateData
	
	#User CFGUTIL to figure out the Model (by deviceType ID) and current
	#version of iPadOS running.
	deviceType=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" get deviceType" 2</dev/null)
	firmwareVersion=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" get firmwareVersion" 2</dev/null)

	if [ "$DEBUG" = "Y" ]; then
		echo "We are looking at a device with type ($deviceType) running firmware version ($firmwareVersion)"
	fi

	#Cat the fie of Apple update data.  Use AWK to print out everything until we hit the device we
	#have.  Now AWK again to find out waht the latest version attributed is.  Use cut to get us down to just
	#a variable.
	AwkWithDeviceVariable=$(echo "{print} /$deviceType/ {exit}")
	GetOSVersion=$(cat /tmp/data.json | awk "$AwkWithDeviceVariable" | grep ProductVersion | tail -1 | cut -d ':' -f 2 | cut -d '"' -f 2)

	#Test data we got back.
	if [ -z "$GetOSVersion" ]; then
		echo "Lookup of supported iOS/iPadOS didn't work.  Cant check update status."
	elif [ "$DEBUG" = "Y" ]; then
		echo "Apple updates site says $deviceType should be running $GetOSVersion"
	fi


	autoload is-at-least

	#If versions match we can mobe on
	if [ "$firmwareVersion" = "$GetOSVersion" ]; then
		echo "iPad is running latest available ($firmwareVersion.)  No update necessary."
		WIPEIT="FALSE"

	elif is-at-least "$firmwareVersion" "$GetOSVersion"; then
		echo "This iPad needs updated. OS installed ($firmwareVersion) is older then what is should be ($GetOSVersion)"
		WIPEIT="TRUE"
		
	else
		echo "Couldn't get a lock on what we should do ($firmwareVersion/$GetOSVersion) so no update will be called for."
		WIPEIT="FALSE"
	fi
	
	# # Build numbers can be found here:
	# # https://en.wikipedia.org/wiki/IOS_version_history#iOS_15_/_iPadOS_15
	# BaseVersion=$(echo "$buildVersion" | cut -c1-2 )
	# SubVersion=$(echo "$buildVersion" | cut -c1-3 )
	#
	# if [ "$BaseVersion" -lt "17" ]; then
	# 	log_line "iPadOS less than iPadOS 13..  Wipe it-> $buildVersion"
	# 		WIPEIT="TRUE"
	#
	# elif [ "$BaseVersion" = "18" ]; then
	# 	log_line "iPadOS 14..  Wipe it-> $buildVersion"
	# 		WIPEIT="TRUE"
	#
	# elif [ "$SubVersion" = "19A" ]; then
	# 	log_line "iPadOS 15.0..  Wipe it-> $buildVersion"
	# 		WIPEIT="TRUE"
	#
	# elif [ "$SubVersion" = "19B" ]; then
	# 	log_line "iPadOS 15.1..  Wipe it-> $buildVersion"
	# 		WIPEIT="TRUE"
	#
	# elif [ "$SubVersion" = "19C" ]; then
	# 	log_line "iPadOS 15.2..  Wipe it-> $buildVersion"
	# 		WIPEIT="TRUE"
	#
	# elif [ "$buildVersion" = "19D50" ]; then
	# 	log_line "iPadOS 15.3..  Wipe it-> $buildVersion"
	# 	WIPEIT="TRUE"
	#
	# elif [ "$buildVersion" = "19D52" ]; then
	# 	log_line "iPadOS 15.3.1.  Wipe it-> $buildVersion"
	# 	WIPEIT="TRUE"
	#
	# elif [ "$buildVersion" = "19E241" ]; then
	# 	log_line "iPadOS 15.4.  GOOD."
	# 	WIPEIT="TRUE"
	#
	# elif [ "$buildVersion" = "19E258" ]; then
	# 	log_line "iPadOS 15.4.1.  GOOD."
	# 	WIPEIT="FALSE"
	#
	# else
	# 	log_line "Not sure what we got here ($buildVersion)so wipe it."
	# 	WIPEIT="TRUE"
	# fi
}

#Check iPadOS version
iPadOSInstallVersion() {
	#buildVersion comes from cfgutil exec -a <script> like UDID and ECID does.
	log_line "($ECID) Our Build Version is=> ($buildVersion)"
	
	#Call build version check above
	CheckBuildVersion
	if [ "$WIPEIT" = "TRUE" ]; then
		
		HayLookAtMe "iPad needs updated ($buildVersion)"

		#Call to RESTORE the iPad
		FullPressWipe=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" restore" 2>/dev/null)

		if [ "$?" = "1" ]; then
			log_line "RESTORE/UPDATE: Epic Fail on $ECID / ($UDID).  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			
			HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
			exit 1

		else
			log_line "RESTORE/UPDATE: Success ($UDID) - Next Steps will happen when iPad boots back up."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			HayLookAtMe "iPad Update SUCCESS.."
			
			#Dont exit..  CFGUTIL doesnt see restore when done to an awake ipad as
			#a reconnection.
			#exit 0
		fi
	
	else
		HayLookAtMe "iPadOS is current ($firmwareVersion)"
	fi
}

#STEP 4-> Install temporary Wifi Profile on Device.  This needs to exist long enough
# to get iPad on regular network.  In our case I have a fall back network of GSD_Unsecured
# the iPad can use no matter what.
InstallProfileDevice() {
	#$CFGUTIL restore
	DoIT=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" install-profile $TEMPORARYWIFIPROFILE" 2>/dev/null | tail -1)
	 log_line "INSTALL-WIFI: Error Code Status ($?)"
	 log_line "INSTALL-WIFI: Results: $DoIT"
	
	log_line "$DoIT"
	
	log_line "INSTALL-WIFI: WiFi Profile Installed on $ECID, waiting for it to initialize.."
	
	#We need to monitor this... Its a step that can fail and then put us into an infinite loop.
	WAITCounter="0"
	
	#Loop until we can talk to device successfully.
	while [ 1 ]; do
	
		#Escape hatch..  if we wait 60s and its still not activated FAIL.
		if [ "$WAITCounter" -gt 60 ]; then
			log_line "INSTALL-WIFI: Something went wrong with $Refer2MeAs.  We've waited $WAITCounter seconds.  Aborting preparation!"
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			exit 1
		fi
	
		#Check to see if iPad is activated
		RWeActivated=$(cfgutil --ecid $ECID get activationState 2>/dev/null)

		#If iPad is activated lets move on.
		if [ "$RWeActivated" = "Activated" ]; then
			log_line "INSTALL-WIFI: $Refer2MeAs is activated.  Moving on!"
			break
			
		else
			#If we are here its because the device is not activated..
			#Lets wait..
			log_line "INSTALL-WIFI: Waiting for $ECID to come back to us.... ($Devicepairingstate)"
			sleep 5
			#Add 5 seconds to the WaitCounter
			let WAITCounter=WAITCounter+5
			log_line "INSTALL-WIFI: We have waited $WAITCounter seconds on $ECID so far..."
		fi
	done
}

#STEP 5-> Run iPad through DEP process and let MDM take over from there.
PrepareDevice() {
	#We need to monitor this... Its a step that can fail and then put us into an infinite loop.
	WAITCounter="0"
	#Loop until we can talk to device successfully.
		while [ 1 ]; do
			#Prepare Device
			
			if [ "$WAITCounter" -gt 60 ]; then
				log_line "PREPARE: Something is wroung with $Refer2MeAs.  We've waited $WAITCounter seconds.  Aborting prepare!"
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "$Refer2MeAs never came back.  DFU and try again..."
				exit 1
			fi
			
			GetDeviceState=$(/usr/local/bin/cfgutil --ecid "$ECID" get bootedState isPaired 2>/dev/null)
			Devicebootstate=$(echo "$GetDeviceState" | grep -a1 bootedState: | tail -1)
			Devicepairingstate=$(echo "$GetDeviceState" | grep -a1 isPaired: | tail -1)
			
			log_line "$ECID--> ($Devicebootstate) / ($Devicepairingstate)"
			
			#if iPad is Booted and paired we should be able to finish --THIS SHOULD BE AND but I couldnt get it to work:(
			if [ "$Devicebootstate" = "Booted" ]; then
				log_line "CHECK FOR BOOTED STATUS"
				if  [ "$Devicepairingstate" = "yes" ]; then
					log_line "CHECK FOR PAIRING STATE YES"
					DoIT=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" prepare --dep --skip-language --skip-region"  2>/dev/null)
				
					if [ "$?" = "0" ]; then
						log_line "PREPARE: Welcome back $ECID.  Continuing...."
						break
						
					else
						log_line "PREPARE: $ECID ($Refer2MeAs) is prepared.. but double check it."
						break
					fi
				else
					log_line "PREPARE: Waiting for $ECID to come back to us.... (booted, not paired)"
					sleep 5
					#Add 5 seconds to the WaitCounter
					let WAITCounter=WAITCounter+5
					log_line "PREPARE: We have waited $WAITCounter seconds on $ECID so far..."
					HayLookAtMe "Waiting for $Refer2MeAs to come back..."
			fi
				
			else
				#If we are here its because the device is either not booted or not paired.
				#Lets wait..
				log_line "PREPARE: Waiting for $ECID to come back to us...."
				sleep 5
				#Add 5 seconds to the WaitCounter
				let WAITCounter=WAITCounter+5
				log_line "PREPARE: We have waited $WAITCounter seconds on $ECID so far..."
				HayLookAtMe "Waiting for $Refer2MeAs to come back..."
			fi
		done
}

###THIS REALLY SHOULD BE REWROTE TO LEAN ON MOSBasic instead of going it alone.  If we rely on MOSBasic
###As our code evolves over there we automatically benefit here.
WipeOTAMosyle() {
	#Build Query.  Just asking for current data on last beat, lostmode status, and location data if we can get it.
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"serial_numbers\":[\"$DeviceSERIAL\"],\"specific_columns\":\"date_last_beat\"}}"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices')
	LASTBEAT=$(echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | perl -pe 's/.*"date_last_beat":"?(.*?)",*.*/\1/' | head -1 )

	#Figure out how many hours ago last beat was
	current_time=$(date +%s)
	current_time=$(expr "$current_time" / 3600 )
	before_time=$(expr "$LASTBEAT" / 3600 )
	hoursago=$(expr "$current_time" - "$before_time" )

	log_line "Hours Ago-> ($hoursago)"
	
	if [ "$hoursago" -lt 12 ]; then
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) iPad last checked in $hoursago, less than 12..  Attempting Over the Air Wipe."
		HayLookAtMe "Last check in $hoursago ago.  Attempting OTA Wipe."

		content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"wipe_devices\"}]}"
		log_line "--> $content <--"
		curl  --silent --output /dev/null -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops'
		
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) OTA wipe device sent...  All we can do now is hope.  Give it 5..  Doesn't work out"
		log_line "then Put iPad in DFU or Factory Recovery Mode and try again."
		HayLookAtMe "OTA Wipe sent...  Give it a few.  If nothing happens try DFU mode."
		
		#Remove our tmp file so when iPad comes back... if it comes back we start the cycle over again.
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		exit 1
		
	else
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) / $DeviceSERIAL / $ASSSETTAG iPad last checked in $hoursago, more than 12..  Not attempting Over the Air Wipe."
		log_line "WIPE VIA MOSYLE: Epic Fail on $ECID.  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		HayLookAtMe "Last check in way too many hours ago ($hoursago) not trying OTA Wipe...  ${Red}EPIC FAIL!"
		exit 1
	fi
}

MosyleTiddyUp() {
	if [ "$ISSHARED" = "TRUE" ]; then
		log_line "MosyleTiddyUp: $Refer2MeAs is a Shared iPad.  Will not Limbo."
		HayLookAtMe "Shared iPad.  Not sending to Limbo."
	else
		log_line "MosyleTiddyUp: Sending $Refer2MeAs to Limbo"
		
		
		#Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd
		content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"change_to_limbo\"}]}"
		APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops')

		CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"')

		if [ "$CMDStatus" = "DEVICES_NOTFOUND" ]; then
			log_line "MosyleTiddyUp: Device not found in Mosyle.  Can't Limbo!"
			HayLookAtMe "Sending iPad to Limbo ${Red}FAILED!"
			

		elif [ "$CMDStatus" = "COMMAND_SENT" ]; then
			log_line "MosyleTiddyUp: Device Sent to Limbo in Mosyle; Success!"
			HayLookAtMe "Sending iPad to Limbo."
		fi
	fi

	#lets also tell Mosyle to clear any back commands on the device.
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"clear_commands\"}]}"
	APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops')

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"')
	log_line "MosyleTiddyUp: Told Mosyle to clear any back commands too for $Refer2MeAs -- RESULT-> $CMDStatus"
	HayLookAtMe "Clearing Back Log Commands.."

	#Send commands to Mosyle to disable Lost Mode.
	#Often we wipe devices which are returned from kids who have left
	#the district.  This stops us from doing one more step.
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"disable\"}]}"
	APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode')

	CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"')
	log_line "MosyleTiddyUp: Told Mosyle to Remove Lost mode for $Refer2MeAs -- RESULT-> $CMDStatus"
	
	HayLookAtMe "Disabling Lost Mode.."
	
	###I'm undecided on this right now.  In one respect if I am processing the iPad because it
	###has been turned in then we should strip tags, but if we are just using this script to process
	###a wipe then we wouldn't want to purge tags.  Will need to revisit this.  Maybe in conjunction
	###with a call to IIQ to see if the device is assigned.
	# #Remove tags from iPad
	# content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"serialnumber\":\"$DeviceSERIAL\",\"tags\":\"\"}]}"
	# APIOUTPUT=$(curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/devices')
	#
	# CMDStatus=$(echo "$APIOUTPUT" | cut -d ":" -f 4 | cut -d "," -f 1 | tr -d '"')
	# log_line "GATHERDATA: Told Mosyle to Remove tags for $Refer2MeAs -- RESULT-> $CMDStatus"
}


HayLookAtMe() {
	# #Define colors
	# Red=`tput ${TPUTTERM} setaf 1`
	# Green=`tput ${TPUTTERM} setaf 2`
	# Yellow=`tput ${TPUTTERM} setaf 3`
	# Blue=`tput ${TPUTTERM} setaf 4`
	# Magenta=`tput ${TPUTTERM} setaf 5`
	# Cyan=`tput ${TPUTTERM} setaf 6`
	# White=`tput ${TPUTTERM} setaf 7`
	# reset=`tput ${TPUTTERM} sgr0`
	
	RIGHTNOW=`date '+%r'`
	
	echo "${Green}$RIGHTNOW / ${White}$Refer2MeAs--> ${Yellow}$1${reset}"


}

##MOVED TO MOSBasic/Common
# GetAppleUpdateData(){
# 	#This command will dump all of the Apple page which details which version of
# 	#software runs on devices.  File is ordered newest OS on top.
# 	curl 'https://gdmf.apple.com/v2/pmv' | /usr/local/munki/munki-python -m json.tool > /tmp/data.json
# }



################################
#   Pre Can we do Work Checks  #
################################
##ALL OF THIS CODE IS IN MOSBasic/Common.  Listing it here is 
##redundant.
# #Make sure TERM variable is set.
# [[ ${TERM}="" ]] && TPUTTERM='-Txterm-256color' \
#                   || TPUTTERM=''
#
# #Define colors
# Red=`tput ${TPUTTERM} setaf 1`
# Green=`tput ${TPUTTERM} setaf 2`
# Yellow=`tput ${TPUTTERM} setaf 3`
# Blue=`tput ${TPUTTERM} setaf 4`
# Magenta=`tput ${TPUTTERM} setaf 5`
# Cyan=`tput ${TPUTTERM} setaf 6`
# White=`tput ${TPUTTERM} setaf 7`
# reset=`tput ${TPUTTERM} sgr0`


log_line "DEPLOY--> $1"
echo "${Cyan}$ECID / $UDID / $buildVersion  <--Has entered the Fray...${reset}"

#Note the pid of this running script.
PIDOFME="$$"

log_line "Pid of this script is $PIDOFME"

#Which Wifi profile to use
if [ "$DEPLOYMODE" = "WIPEONLY" ]; then
	log_line "WIPE ONLY MODE SPECIED. Will wipe and go no further."
	JustWipe="Y"
elif [ "$DEPLOYMODE" = "LOANER" ]; then
	log_line "Loaner Mode Specified.  Will act accordingly."
	#This network is our normal use network.  Because this is a loaner we want this
	#iPad always on this network (district wide network)


	#Make sure our wifi profile is available
	if [ ! -r "$LOANERWIFIPROFILE" ]; then
		log_line "Wifi profile $LOANERWIFIPROFILE to be used but can't be found.  EPIC FAIL."
		exit 1
		
	else
		JustWipe="N"
		TEMPORARYWIFIPROFILE="$LOANERWIFIPROFILE"
	fi
	
else
	#This profile is for a temporary network that only exists in the IT office. 
	log_line "No deploy method specified (WIPEONLY/LOANER) so assuming normal operation."
	if [ ! -r "$LIMBOWIFIPROFILE" ]; then
		log_line "Wifi profile $LIMBOWIFIPROFILE to be used but can't be found.  EPIC FAIL."	
		exit 1
	else
		TEMPORARYWIFIPROFILE="$LIMBOWIFIPROFILE"
	fi
fi


#Make sure ECID is not blank.  If it is we can't do anything.  As we are launched
#by CFGUTIL I can't see how this could happen, but best to make sure.
if [ -z "$ECID" ]; then
	log_line "ECID doesn't appear to have been handed off to this script.  Can't continue."
	exit 1
else
	log_line "ECID provided was $ECID."
fi

#Are we working on this device already?  Dont want to operate on the same device twice.  This
#can happen when a device resets then comes back.  The script that started the action is waiting
#for it to come back.
if [ -f "$TMPLOCATION/CFGUTIL_$ECID.txt" ]; then
	log_line "EPIC FAIL: $ECID appears to already be involved with another process.  Skipping."
	
	Refer2MeAs="$ECID"
	
	if [ "$DEPLOYMODE" = "LOANER" ]; then
		HayLookAtMe "Loaner Mode enabled, This device is currently Ready to Deploy. ${Green}Skipping."
		exit 0
	else
		HayLookAtMe "Already involved with another process. ${Red}EPIC FAIL!"
		exit 1
	fi
	
else
	touch "$TMPLOCATION/CFGUTIL_$ECID.txt"
fi

#ID That iPad...  If we cant get a confirmed hit from MOSBasic that its a known
#device then use UDID as ID.  We will need more logic in the future when dealing with
#NEW devices.. but we will cross that bridge when we get there.
if [ -z "$UDID" ]; then
	log_line "Device wont tell us its UDID.  Attempting to jump right to Restore."
	
	GetDeviceState=$(/usr/local/bin/cfgutil --ecid "$ECID" get bootedState isPaired 2>/dev/null )
	Devicebootstate=$(echo "$GetDeviceState" | grep -a1 bootedState: | tail -1)
	Devicepairingstate=$(echo "$GetDeviceState" | grep -a1 isPaired: | tail -1)
	
	if [ "$Devicebootstate" = "Recovery" ]; then
			HayLookAtMe "iPad is in DFU Mode....  Passing forward."
			
	else

		Refer2MeAs="$ECID"
		HayLookAtMe "No UDID detected... Wait 30s before we do anything."
		sleep 30

		GETUDID=$(bash -c "/usr/local/bin/cfgutil --ecid "$ECID" get UDID")

		if [ -z "$GETUDID" ]; then
			HayLookAtMe "We waited 30s and still can't get UDID..  Going for the Hail Mary and doing a restore."
			#Call restore routine.
			RestoreDevice

		else
			UDID="$GETUDID"

			#NOTE THIS FILE WE ARE LOOKING THROUGH COMES FROM MOSBasic.  
			FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 1,2,5 | grep "$UDID")
			#Strip FoundIt down to JUST THE SERIAL #
			ASSETTAG=$(echo "$FoundItIOS" | cut -d$'\t' -f 3)
			DeviceSERIAL=$(echo "$FoundItIOS" | cut -d$'\t' -f 2)

			log_line "$ECID / $UDID / $ASSETTAG / $DeviceSERIAL"

			if [ -z "$FoundItIOS" ]; then
				log_line "IDTHATIPAD: Couldn't find $UDID in MOSBasic cache files."
				Refer2MeAs="$UDID"

				HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"

			else
				Refer2MeAs="$ASSETTAG"

				HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"
			fi

		fi
	fi
else
	
	#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
	#NOTE THIS FILE WE ARE LOOKING THROUGH COMES FROM MOSBasic.
	FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 1,2,5 | grep "$UDID")
	#Strip FoundIt down to JUST THE SERIAL #
	ASSETTAG=$(echo "$FoundItIOS" | cut -d$'\t' -f 3)
	DeviceSERIAL=$(echo "$FoundItIOS" | cut -d$'\t' -f 2)
	
	log_line "$ECID / $UDID / $ASSETTAG / $DeviceSERIAL"

	if [ -z "$FoundItIOS" ]; then
		log_line "IDTHATIPAD: Couldn't find $UDID in MOSBasic cache files."
		Refer2MeAs="$UDID"
		
		HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"

	else
		Refer2MeAs="$ASSETTAG"
		
		HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"
	fi
fi

#Check if iPad is shared mode per MDM.  This function comes from
#MOSBasic common.
IsThisiPadSharedMode 



##THIS WAS MOVED TO MOSBasic/Common
# ####################################################
# # Check for our data file of Apple updates.  If we don't
# # have it or its older than 6hrs pull it again.
# ####################################################
# if [ ! -s "/tmp/data.json" ]; then
# 	echo "Data file is missing.  Must create."
# 	GetAppleUpdateData
# elif [ `find "/tmp/data.json" -mmin +360 | egrep '.*'` ]; then
# 	echo "Data file is out of date.  Must grab new data."
# 	GetAppleUpdateData
# else
# 	echo "Data file is found and appears new enough.  Continuing."
# fi


#########
# Need code to detect MarkerFilez dir and make if doesn't exit
# also Logs dir.
#
#
################################
#            DO WORK           #
################################
HayLookAtMe "Initial iPad Status Check"

log_line "IPAD STATUS: Checking iPad current Status $ECID"
#Do a Quick Check on the iPad we just got..  If its unactivated we don't need to 
#wipe it..  Otherwise always wipe.
RWeActivated=$(cfgutil --ecid $ECID get activationState 2> /dev/null)
if [ "$RWeActivated" = "Unactivated" ]; then
	log_line "IPAD STATUS: $ECID appears to be in a wiped state."
	HayLookAtMe "iPad is wiped.  Checking iPadOS Version."
	
	log_line "IPAD STATUS: Checking Build Version and updating if needed."
	iPadOSInstallVersion	
else
	#All other cases perform restore action.
	log_line "RESTORE: Activated Status ($RWeActivated)"
	RestoreDevice
fi

log_line "RESTORE: Restore step success on $ECID"

#Call Mosyle TiddyUp function.  This will put iPad into
#Limbo (as long as its not shared,) clear back log commands,
# and disable lost mode.  We do DLM blindy.. if its not enabled
# we wasted a few seconds of API time and if it is enabled well
# we stopped ourself some irritation later.
MosyleTiddyUp

if [ "$JustWipe" = "Y" ]; then
	log_line "Just Wipe Mode enabled.  $ECID ($ASSETTAG / $DeviceSERIAL) not being prepared any further."
	HayLookAtMe "Wipe Only..  This iPad is DONE!"
	
else
	#Step 4
	log_line "INSTALL_WIFI: Preparing to install wifi profile on $ECID ($ASSETTAG / $DeviceSERIAL)"
	HayLookAtMe "Installing WiFi profile $TEMPORARYWIFIPROFILE"
	InstallProfileDevice

	log_line "INSTALL_WIFI: Wifi Profile deployed to $ECID ($ASSETTAG / $DeviceSERIAL)"
	#Step 5
	log_line "PREPARE: Preparing to finialize $ECID ($ASSETTAG / $DeviceSERIAL)"
	HayLookAtMe "Running HELLO SCREEN prep steps"
	PrepareDevice

	log_line "PREPARE: $ECID ($ASSETTAG / $DeviceSERIAL) has finished prepare step..  Its up to MDM now."
	HayLookAtMe "iPad ${Green}COMPLETE."
fi



#Every bad error status has an exit code.  If we got this far asssume success.
if [ -z "$ASSETTAG" ]; then
	log_line "iPad with serial number $DeviceSERIAL has completed!"
else
	log_line "iPad with asset tag $Refer2MeAs has completed!"
fi

if [ "$DEPLOYMODE" = "LOANER" ]; then
	log_line "This is a loaner device.  Not deleting temporary marker file."
	HayLookAtMe "iPad is a loaner ${Green}KEEPING MARKER FILE."
else
		#Remove our holder file so if we unplug the iPad and plug it back
	#in then it will wipe all over again.
	rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
fi

