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

#Find by Asset Tag
BYASSTAG=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$1" )
echo "BYASSTAG-> $BYASSTAG"
if [ ! -z "$BYASSTAG" ]; then
	echo "Tag Check-> $BYASSTAG"
	line="$BYASSTAG"
	ParseIt_ios 
	echo "UDID=$UDID"
	echo "DeviceSerialNumber=$DeviceSerialNumber"
	echo "CURRENTNAME=$CURRENTNAME"
	echo "TAGS=$TAGS"
	echo "ASSET TAG=$ASSETTAG"
	echo "LASTCHECKIN=$LASTCHECKIN"
	echo "ENROLLMENT_TYPE=$ENROLLMENT_TYPE"
	echo "USERID=$USERID"
	echo "ASSIGNED TO=$NAME"
	
	#We had a good hit.  Stop.
	exit 0
fi

#Find by USERID
BYUSERID=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$1" )
echo "BYASSTAG-> $BYUSERID"
if [ ! -z "$BYUSERID" ]; then
	echo "Tag Check-> $BYUSERID"
	line="$BYUSERID"
	ParseIt_ios 
	echo "UDID=$UDID"
	echo "DeviceSerialNumber=$DeviceSerialNumber"
	echo "CURRENTNAME=$CURRENTNAME"
	echo "TAGS=$TAGS"
	echo "ASSET TAG=$ASSETTAG"
	echo "LASTCHECKIN=$LASTCHECKIN"
	echo "ENROLLMENT_TYPE=$ENROLLMENT_TYPE"
	echo "USERID=$USERID"
	echo "ASSIGNED TO=$NAME"
	
	#We had a good hit.  Stop.
	exit 0
fi

#Find by Serial
BYSERIAL=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | grep "$1" )
if [ ! -z "$BYSERIAL" ]; then
	echo "Tag Check-> $BYSERIAL"
	line="$BYSERIAL"
	ParseIt_ios 
	echo "UDID=$UDID"
	echo "DeviceSerialNumber=$DeviceSerialNumber"
	echo "CURRENTNAME=$CURRENTNAME"
	echo "TAGS=$TAGS"
	echo "ASSET TAG=$ASSETTAG"
	echo "LASTCHECKIN=$LASTCHECKIN"
	echo "ENROLLMENT_TYPE=$ENROLLMENT_TYPE"
	echo "USERID=$USERID"
	echo "ASSIGNED TO=$NAME"
	
	#We had a good hit.  Stop.
	exit 0
fi

###################
# If we are here then we got no hits.
cli_log "No hits for $1.  Please double check your info and try again."
exit 1


