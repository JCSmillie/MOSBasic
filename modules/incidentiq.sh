#!/bin/zsh

####File with IncidentIQ Keys in the form of:
# apitoken="S0M3KeY"
# siteid="IIQ_SiteID"
# baseurl="https://YourSite.incidentiq.com/api/v1.0
source $LOCALCONF/.incidentIQ
#apitoken, siteid, and baseurl all come from the source file above


USERLOOKUP() {
	USER2Search="$1"
	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/Users/Search/$USER2Search"

	#Do initial query with Serial # and cache the result
	InitialQuery=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query")
	#echo "$InitialQuery"

	Username=$(echo "$InitialQuery" | grep "Username" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" | head -1 | cut -d '@' -f 1)
	#Hack off white spaces
	Username="${Username//[[:space:]]/}"

	FirstName=$(echo "$InitialQuery" | grep "FirstName" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" )
	#Hack off only intial white spaces.  We 
	#cant take them all because if the user has
	#two names it will jam them together.
	FirstName="${FirstName/ /}"
	
	LastName=$(echo "$InitialQuery" | grep "LastName" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" )
	#Hack off only intial white spaces.  We 
	#cant take them all because if the user has
	#two names it will jam them together.
	LastName="${LastName/ /}"
	
	SchoolIdNumber=$(echo "$InitialQuery" | grep "SchoolIdNumber" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" | head -1 )
	#Hack off white spaces
	SchoolIdNumber="${SchoolIdNumber//[[:space:]]/}"
	
	Grade=$(echo "$InitialQuery" | grep "Grade" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" | head -1 )
	#Hack off white spaces
	Grade="${Grade//[[:space:]]/}"
	
	Homeroom=$(echo "$InitialQuery" | grep "Homeroom" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" | head -1 )
	#Hack off white spaces
	Homeroom="${Homeroom//[[:space:]]/}"
	
	LocationName=$(echo "$InitialQuery" | grep "LocationName" | cut -d ':' -f 2 | cut -d ',' -f 1  | tr -d \" | head -1 )
	#Hack off only intial white spaces.  We 
	#cant take them all because if the user has
	#two names it will jam them together.
	LocationName="${LocationName/ /}"
}




DEVICELOOKUP() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

TICKETLOOKUP() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

SUBMITTICKET() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

INVENTORYASSSIGNDEVICE() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

INVENTORYUNASSIGNDEVICE() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}