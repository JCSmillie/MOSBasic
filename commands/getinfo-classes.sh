#!/bin/zsh
################################################################
#
#	getinfo-classes.sh  
#		General support to sorta Expo off that we have class listings now in the export.  This was built
#		more so as a example of how the data could be worked with.  For now I just needed the dumped
#		data for reasons (see code comments.)
#
#		If I would come back to this there would definately need to be some sort of limiter on search and
#		Im not even sure what that looks like.
#
#		JCS - 9/24/25  -v1
#
################################################################

################################
#            Variables - Changable                                       #
################################
#Locally declare Debug
#MB_DEBUG="N"	#Make capital Y to enable debug

#Classes - EDUONLY
TEMPOUTPUTFILE_MERGEDClasses="/tmp/Mosyle_active_Classes_MergedClasses.txt"

################################
#            Variables - Script Only                                     #
################################
#These variables are more or less inside variables and
# shouldnt be messed with as they are depended on
# not only throughout this script but possibly others.
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'
CMDRAN="GETINFO-CLASSES"

################################
#            Functions                                                          #
################################
# You will note that we have more functions here dedicated
# to this cause then usual.  Classroom support is more so 
# "The Dump" then anything else.  My figuring right now is
# that it will be most powerful for me two ways:
#	1-> Deploy Custom Tag to Students Devices based on class
#		membership.  Since Mosyle doesnt have the ability to 
#		EXCLUDE based on Class membership, but YOU CAN
#		EXCLUDE on tag thats my solution.
#	2-> MUSKY....  I want to build a page in Musky that will
#		Let the teachers see a display of their class just like
#		the loaner Manager does today.  The dumped data
#		as is will be parsed directly.
#	-JCS	-	9-24-25
ParseIt_MosyleClass() {
	#If "MCline" varible isnt filled then assume we gave
	#data when the command was ran from the $1 variable.
	if [ -z "$MCline" ]; then
		MCline="$1"
		
	elif [ -z "$MCline" ] && [ -z "$1" ]; then
		cli_log "No data given.  Can't parse!"
		exit
	fi
	
	MosyleClassID=$(echo "$MCline" | cut -f 1 -d';')
	MosyleClassName=$(echo "$MCline" | cut -f 2 -d';')
	MosyleClassLocation=$(echo "$MCline" | cut -f 3 -d';')
	MosyleClassTeacher=$(echo "$MCline" | cut -f 4 -d';')
	MosyleClassStudents=$(echo "$MCline" | cut -f 5 -d';')
	MosyleClassCoordinators=$(echo "$MCline" | cut -f 6 -d';')
}

GetInfo_MosyleClass() {
	
	MCSearchTerm="$1"
	
	# Field 1 -> Class ID
	# Field 2 -> Class Name
	# Field 3 -> Class Location
	# Field 4 -> Class Teacher
	# Field 5 -> Class Students
	# Field 6 -> Class Cordinators (think Teacher #2)
	MOSB_C_Query=$(cat "$TEMPOUTPUTFILE_MERGEDClasses" | grep "$MCSearchTerm")
	
	#Search yeilded no result.
	if [ -z "$MOSB_C_Query" ]; then
		cli_log "Search for $MCSearchTerm failed..  No results."
		
		#Debug extra info
		if [ "$MB_DEBUG" = "Y" ]; then
			cli_log "We searched for ($MCSearchTerm)"
			cli_log "Results (RAW)= ($MOSB_C_Query)"
		fi
		
		#Drop out.
		exit 1
	else
		#Check to see how many results we got.
		WCC=$(echo "$MOSB_C_Query" | wc -l )
		WCC="${WCC//[[:space:]]/}"
		
		#Debug extra info
		if [ "$MB_DEBUG" = "Y" ]; then
			cli_log "We searched for $MCSearchTerm"
			cli_log "WC=$WCC"
			cli_log "Results (RAW)= $MOSB_C_Query"
		fi
	fi

	#If we got more than 1 result lets use a loop to look
	#each one up.
	if [ "$WCC" -gt "1" ]; then
		cli_log "Search for $MCSearchTerm gave multiple results."
		
		#Loop through all results one at a time and display.
		echo "$MOSB_C_Query" | while read FoundOne; do

			FoundOne=$(cat "$TEMPOUTPUTFILE_MERGEDClasses" | grep "$FoundOne")
			ParseIt_MosyleClass "$FoundOne"

			echo " ID-> $MosyleClassID"
			echo " Class Name-> $MosyleClassName"
			echo " Class Location-> $MosyleClassLocation"
			echo " Class Teacher-> $MosyleClassTeacher"
			echo " Class Students-> $MosyleClassStudents"
			echo " Class Cordinators-> $MosyleClassCoordinators"
			echo "=====-------------====="
		done
		
	else
		#Only one result ($WCC=1 & $MOSB_C_Query is not empty)
		echo "ID-> $MosyleClassID"
		echo "Class Name-> $MosyleClassName"
		echo "Class Location-> $MosyleClassLocation"
		echo "Class Teacher-> $MosyleClassTeacher"
		echo "Class Students-> $MosyleClassStudents"
		echo "Class Cordinators-> $MosyleClassCoordinators"
	fi
}

################################
#            DO WORK                                                        #
################################
#Debugging....
if [ "$MB_DEBUG" = "Y" ]; then
	cli_log "Variable 1-> $1"
	cli_log "Variable 2-> $2"
	cli_log "Variable 3-> $3"
	cli_log "Variable 4-> $4"
fi

#Make sure data points exists and we can read it
if [[ -r "$TEMPOUTPUTFILE_MERGEDClasses" && -s "$TEMPOUTPUTFILE_MERGEDClasses" ]]; then
	cli_log "Reference file available.  Continuing."
else
	cli_log "Reference file is missing, unreadable, or empty.  FAIL!!"
	exit 1
fi

#Make sure we were given criteria to do a look up
if [ -z "$1" ]; then
	cli_log "No lookup point < teacher userid / student userid / classid / random > given..  Can't do this."
	exit 1
else
	#Call Functions to handle Lookup and display if found 
	GetInfo_MosyleClass "$1"
fi

