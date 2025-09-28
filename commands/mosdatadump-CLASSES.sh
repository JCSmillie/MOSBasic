#!/bin/zsh

################################################################
#
#	mosdatadump-CLASSES.sh  
#		Script to query Mosyle and return a list of class names and the student usernames 
#		into a single file.  
#
#		JCS - 9/2/2025
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="classdump"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#Classes - EDUONLY
TEMPOUTPUTFILE_MERGEDClasses="/tmp/Mosyle_active_Classes_MergedClasses.txt"





#The source file is a local file which holds a variable containing
#our MosyleAPI key.  Should look like:
#     MOSYLE_API_key="<<<<<<<<OUR-KEY>>>>>>>>"
# This file should have rights on it as secure as possible.  Runner
# of our scripts needs to read it but no one else.
#MOSBasic scripts are used here and relied on
BAGCLI_WORKDIR=$(readlink /usr/local/bin/mosbasic)
#Remove our command name from the ou	 above
BAGCLI_WORKDIR=${BAGCLI_WORKDIR/mosbasic/}
export BAGCLI_WORKDIR
 
source "$BAGCLI_WORKDIR/config"

 #shellcheck source=common
. "$BAGCLI_WORKDIR/common"
LOG=/dev/null

#################################
#            Functions          #
#################################
log_line() {
	echo "$1"
}

ParseIt() {
	ClassID=$(echo "$line" | cut -f 1 -d$'\t')
	ClassName=$(echo "$line" | cut -f 2 -d$'\t')
	Students=$(echo "$line" | cut -f 3 -d$'\t' | tr -d \" | tr -d [ | tr -d ])
}

#According to documentation avaialble 9/2/25 these are the possible columns.
# id, class_name, course_name, location, teacher, students, coordinators, account
# I'm not querying course_name or account currently -JCS
Generate_JSON_ClassDUMPPostData() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"options": {
		"page": "$THEPAGE",
		"specific_columns": ["id","class_name","location","teacher","students","coordinators"],
		"page_size": "$NumberOfReturnsPerPage"
	}
}
EOF
}


GetClassData(){
	GetBearerToken

	#This is a new CURL call with JSON data - JCS 11/8/23
	output=$(curl -s --location 'https://managerapi.mosyle.com/v2/listclasses' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_ClassDUMPPostData)") 
	
	#Drop out whats returned to file.  We do this DIRECT
	#so that if error is returned we can see it here BEFORE
	#the script dumps out.
	echo "$output" > /tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt

}

#Yes unlike prior Mosyle processors this one uses
#jq to process the JSON.  While MOSBasic initially
#started out as what can I do with Shell and MosyleAPI
#my shift is moving towards how can MOSBasic serve
#musky.  As such no shortcuts will be taken, but reliability
#changes would be considred. -JCS 9/2/25
##
#Process return data from JSON to csv but using ";" as seperator.
convert_mosyle_json_to_csv_inline() {
  jq -r '
    if (.response.classes != null and (.response.classes | type == "array")) then
      .response.classes[] |
      [
        .id,
        .class_name,
        .location,
        (.teacher // [] | join(",")),
        (.students // [] | join(",")),
        (.coordinators // [] | join(","))
      ] |
      @csv
    else
      empty
    end
  ' 2>/dev/null |
  sed 's/","/;/g; s/^"//; s/"$//' |
  awk 'BEGIN { print "ID;Class Name;Location;Teacher;Students;Coordinators" } { print }'
}

################################
#            DO WORK           #
################################
#Clear out our files
rm -Rf /tmp/Mosyle_active_Classes.txt

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0
DataRequestFailedCount=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	
	#Check for how many failed calls we've made up to
	#last query made by the script.  If more than 5 kill the skip...
	if [ "$DataRequestFailedCount" -gt 5 ]; then
		cli_log "TOO MANY DATA REQUEST FAILURES.  ABORT!!!!!"
		exit 1
	fi

	#Note to log
	cli_log "MOSYLE CLASSES-> Asking MDM for Page $THEPAGE data...."
	#Run the query for $THEPAGE
	GetClassData
	
	#Make sure output has content
	if [ -z "$output" ]; then
	#if [[ ! -z $(cat "/tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt") ]] ; then	
		cli_log "Page $THEPAGE reqested from Mosyle but had no data.  Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		#Jumping to next page
		continue
	fi
	
	#TokenFailures
	LASTPAGE=$(echo "$output" | grep 'accessToken Required')
	if [ -n "$LASTPAGE" ]; then
		#Report last page as issue not this run.
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE CLASSES-> AccessToken error...(Page $THECOUNT)"
		break
	fi
	
	# #Are we on more pages then our max (IE something wrong)
	# if [ "$THECOUNT" -gt "$MAXPAGECOUNT" ]; then
	# 	cli_log "MOSYLE CLASSES-> We have hit $THECOUNT pages...  Greater then our max.  Something is wrong."
	# 	break
	# fi

	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(echo "$output" | grep NO_CLASSES_FOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	#Send the return data (if we gort this far) to convert to csv
	# and drop to local tmp file.
	echo "$output" | convert_mosyle_json_to_csv_inline >> /tmp/Mosyle_active_Classes.txt
done

#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.
if [ ! "$MB_DEBUG" = "Y" ]; then
	#Unless we are debugging then we need to cleanup after ourselves
	rm /tmp/MOSBasicRAW-ClassDump-*.txt
else
	cli_log "CLASSES DUMP-> DEBUG IS ENABLED.  NOT CLEANING UP REMAINING FILES!!!!"
fi

#Drop latest grab where it belongs.
cat  /tmp/Mosyle_active_Classes.txt > "$TEMPOUTPUTFILE_MERGEDClasses"

