#!/bin/zsh

################################################################
#
#	SerialinMosyle.sh 
#		Script takes input of a text file full of serials, one
#		serial per line, tells you if that device is in Mosyle
#		currently (IE taking up a license,) and exports to a
#		a file which you can then easily share with Mosyle support
#		to remove those devices from your instance.
#
#		JCS - 2/21/2022  -v1
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

CMDRAN="serialcheck"

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
	cli_log "No file given.  Cant do anything."
	exit 1
	
elif [ ! -r "$1" ]; then
	cli_log "Whatever you told me doesnt appear to be a readable file..  Try again."
	cli_log "Cant read $1"
	exit 1
	
else
	#Make sure we have the latest serial data available.
	cli_log "Doing iosdump,macosdump and userdump in parallel to ensure we are using latest info."
	"$BAGCLI_WORKDIR/commands/mosdatadump-iOS.sh" &
	P1=$!
	"$BAGCLI_WORKDIR/commands/mosdatadump-USERS.sh" &
	P2=$!
	"$BAGCLI_WORKDIR/commands/mosdatadump-Mac.sh" &
	P3=$!	

	wait $P1 $P2 $P3
	
	if [ -z "$2" ]; then
		cli_log "No output specified, using /tmp/StillInMosyle.csv"
		OutputFile="/tmp/StillInMosyle.csv"
	else
		OutputFile="$2"
	fi
	
	rm -Rf "$OutputFile"
	
	#now go ovewr our file
	for DaSerial in `cat "$1"`; do
	
		DEVICESTILLINMOSYLEIPAD=$(grep "$DaSerial" < "$TEMPOUTPUTFILE_MERGEDIOS" )
	
		echo "Checking $DaSerial"
	
		if [ ! -z "$DEVICESTILLINMOSYLEIPAD" ]; then
			echo "Serial number $DaSerial is an iPad and its still in Mosyle"
			echo "$DaSerial, iPad" >> "$OutputFile"
		
		else
			DEVICESTILLINMOSYLEMAC=$(grep "$DaSerial" < "$TEMPOUTPUTFILE_MERGEDMAC" )
			if [ ! -z "$DEVICESTILLINMOSYLEMAC" ]; then
				echo "Serial number $DaSerial is a Mac and its still in Mosyle"
				echo "$DaSerial, Mac" >> "$OutputFile"
			fi
		fi
	done
	
	
	cli_log "If there was serials in your file that also appeared in Mosyle submit $OutputFile to Mosyle support for Removal."
	exit 0

fi

