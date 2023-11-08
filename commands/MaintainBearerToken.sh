#!/bin/zsh
#
########
# Grab Bearer Token
########
# This routine can be called to check that the bearer token
# available to us exists and is good to use.  NOTE token is only
# good for 24hrs after its generated so this need to be checked
# fairly often.  
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


# MOSYLE_API_key="d0a456d2c601dd288d88a48120c849a255c6545512541c14d5da20acc91a2159"
# MOSYLE_API_Username="jsmillie@gatewayk12.org"
# MOSYLE_API_Password="hez8bat_epq*YAK4pba"

Generate_JSON_PostData() {
cat <<EOF
	{"accessToken": "$MOSYLE_API_key",
	"email": "$MOSYLE_API_Username",
	"password": "$MOSYLE_API_Password" }
EOF
}

GetBearerToken() {
	#Using JSON Post data from above try to get BearerToken
	GrabToken=$(curl --include --location 'https://managerapi.mosyle.com/v2/login' \
	--header 'Content-Type: application/json' \
	--data-raw "$(Generate_JSON_PostData)")

	AuthToken=$(echo "$GrabToken" | grep Authorization | cut -d ' ' -f 3 )

	#Make sure we got data back and if so store it.
	if [ -z "$AuthToken" ]; then
		echo "No token given by Mostle.  FAIL."
	
	else
		echo "Token Given.  Storing.."
		echo $AuthToken > ~/.MosyleAPI_BearToken
	fi
}

#Findout last time we touched our token file
BearTokenAge=$(perl -l -e 'print 86400 * -M $ARGV[0]' "$HOME/.MosyleAPI_BearToken")

#A bearer Token is only good for 24 hrs... so we need to make sure
#the file we store in isn't older then say 18hrs.

if [ -f "$HOME/.MosyleAPI_BearToken" ]; then
	cli_log "Tokenfile doesnt exist.  Trying to grab one."
	GetBearerToken
	
elif [ "$BearTokenAge" -gt 54000 ]; then
	cli_log "Token too old.  Need to regenerate."
	
else
	cli_log "Token is good."
	AuthToken=$(cat "$HOME/.MosyleAPI_BearToken")
fi





