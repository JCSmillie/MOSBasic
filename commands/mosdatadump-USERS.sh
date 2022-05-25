#!/bin/zsh

################################################################
#
#	userdump.sh  
#		Script pulls users from Mosyle and sorts them out 
#		into a single file.  
#
#		JCS - 9/28/2021  -v1
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="userdump"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi


################################
#            DO WORK           #
################################
#Remove any prior works generated by this script
rm -Rf "$TEMPOUTPUTFILE_Users"

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"specific_columns\":[\"id\",\"name\",\"managedappleid\",\"type\"],\"page\":$THEPAGE}}"
	cli_log "MOSYLE USERS-> Asking MDM for Page $THEPAGE data...."
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listusers') >> $LOG
	##This has been changed from running inside a variable to file output because there are some characers which mess the old
	#way up.  By downloading straight to file we avoid all that nonsense. -JCS 5/23/2022
	curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listusers' -o /tmp/MOSBasicRAW-Users-Page$THEPAGE.txt

	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-Users-Page$THEPAGE.txt" | grep 'users":\[\]')
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE USERS-> Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	#Preprocess the file.  We need to remove {"status":"OK","response": so can do operations with our python json to csv converter.  Yes
	#I know this is still janky but hay I'm getting there.
	cat /tmp/MOSBasicRAW-Users-Page$THEPAGE.txt  | cut -d ':' -f 3- | sed 's/.$//' > /tmp/MOSBasicRAW-Users-TEMPSPOT.txt
	mv -f /tmp/MOSBasicRAW-Users-TEMPSPOT.txt /tmp/MOSBasicRAW-Users-Page$THEPAGE.txt
	
	#Call our python json to csv routine.  Output will be tab delimited so we can maintain our "tags" together.
	$PYTHON2USE $BAGCLI_WORKDIR/modules/json2csv.py users /tmp/MOSBasicRAW-Users-Page$THEPAGE.txt "$TEMPOUTPUTFILE_Users"
done

#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.
if [ ! "$MB_DEBUG" = "Y" ]; then
	#Unless we are debugging then we need to cleanup after ourselves
	rm -f /tmp/MOSBasicRAW-Users-*.txt
else
	cli_log "iOS CLIENTS-> DEBUG IS ENABLED.  NOT CLEANING UP REMAINING FILES!!!!"
fi
