#!/bin/zsh

################################################################
#
#	macdump.sh  
#		Script pulls all Macs from Mosyle and sorts them out 
#		into other files.  These files are utilized after the
#		fact by other scripts.
#
#		JCS - 2/12/22  -v2
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="MACdump"

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
rm -Rf "$TEMPOUTPUTFILE_MACStu"
rm -Rf "$TEMPOUTPUTFILE_MACTeachers"
rm -Rf "$TEMPOUTPUTFILE_MACLimbo"
rm -Rf "$TEMPOUTPUTFILE_MACShared"
rm -Rf "$TEMPOUTPUTFILE_MERGEDMAC"

#Make Sure Data Storage Directory is ready
#I'm doing this because sometimes things get wonky and
#mosbasic will export pages forever...


#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"mac\",\"specific_columns\":\"deviceudid,serial_number,device_name,tags,asset_tag,userid,enrollment_type,username,date_app_info\",\"page\":$THEPAGE}}"
	#output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices') >> $LOG
	cli_log "MAC CLIENTS-> Asking MDM for Page $THEPAGE data...."
	
	##This has been changed from running inside a variable to file output because there are some characers which mess the old
	#way up.  By downloading straight to file we avoid all that nonsense. -JCS 5/23/2022
	curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices' -o /tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt

	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt" | grep DEVICES_NOTFOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MAC CLIENTS-> Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi
	
	#TokenFailures
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt" | grep 'accessToken Required')
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MAC CLIENTS-> AccessToken error..."
		break
	fi

	cat /tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt

	# #Preprocess the file.  We need to remove {"status":"OK","response": so can do operations with our python json to csv converter.  Yes
	# #I know this is still janky but hay I'm getting there.
	# cat /tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt  | cut -d ':' -f 3- | sed 's/.$//' > /tmp/MOSBasicRAW-Mac-TEMPSPOT.txt
	# mv -f /tmp/MOSBasicRAW-Mac-TEMPSPOT.txt /tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt
	#
	# #Call our python json to csv routine.  Output will be tab delimited so we can maintain our "tags" together.
	# $PYTHON2USE $BAGCLI_WORKDIR/modules/json2csv.py devices /tmp/MOSBasicRAW-Mac-Page$THEPAGE.txt "$TEMPOUTPUTFILE_MERGEDMAC"
done

# # #Build file of all this data now that we've sorted it out and parsed it.
# # #we still need the single/individual files for legacy support of other
# # #scripts but going forward the merge'd file will be the way to go.  
# NOTE these files only create if you set the LEGACYFILES variable in your config
# as I'm the only one who I think has scripts using them I didn't add this to the config
# as it will eventually be phased out - JCS 5/24/22
if [ "$LEGACYFILES" = "Y" ]; then
	cli_log "MAC CLIENTS-> Legacy Files support is enabled.  Creating legacy files for Student, Teacher, Limbo, and Shared."
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "Student" > "$TEMPOUTPUTFILE_MACStu"
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "Teacher" > "$TEMPOUTPUTFILE_MACTeachers"
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "Staff" >> "$TEMPOUTPUTFILE_MACTeachers"
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "Leader" >> "$TEMPOUTPUTFILE_MACTeachers"
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "GENERAL" > "$TEMPOUTPUTFILE_MACLimbo"
	cat "$TEMPOUTPUTFILE_MERGEDMAC" | grep "SHARED" > "$TEMPOUTPUTFILE_MACShared"
fi

#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.
if [ ! "$MB_DEBUG" = "Y" ]; then
	#Unless we are debugging then we need to cleanup after ourselves
	rm -f /tmp/MOSBasicRAW-Mac-*.txt
else
	cli_log "MAC CLIENTS-> DEBUG IS ENABLED.  NOT CLEANING UP REMAINING FILES!!!!"
fi