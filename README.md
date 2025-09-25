# MOSBasic

Easy to use command line tools for interacting with MOSYLE MDM.  In places I also will interact with IncidentIQ ticket system for data.  I'm going to try to run my inventory check module so anyone could easily write their own module for the ticket system they use.  Will post a note about that in the wiki later when we get there.  This command was built for daily use at Gateway School District so we could easily maniplulate devices without having to go to the GUI every time.  It is 
 
 **NOTE** These commands rely on asset tags for reference.  
 
 My goal here is to try to create some simple command line tools using commands and methods which should always be available on any Mac which can let admins quickly do common tasks from the CLI.  Tasks like:
 * Work with tags (add, remove, remove all)
 * Work with Lost Mode (enable, disable, play sound)
 * Compare assignment of device Mosyle vs. IncidentIQ
 * Assign devices single, masss (scan from the command line,) or by file
 * Deassign device (send to Limbo) single, masss (scan from the command line,) or by file
 * Wipe device (requires device to have recently checked in)
 
 **NOTE** There are some pre-requisites for this project now in 2025.  Hoping to keep to the standards though.
 
 Today if you type the _mosbasic_ command with no argument it tells you it can do the following things:
 ```

   __  __  ____   _____ ____            _
  |  \/  |/ __ \ / ____|  _ \          (_)
  | \  / | |  | | (___ | |_) | __ _ ___ _  ___
  | |\/| | |  | |\___ \|  _ < / _` / __| |/ __|
  | |  | | |__| |____) | |_) | (_| \__ \ | (__
  |_|  |_|\____/|_____/|____/ \__,_|___/_|\___|



mosbasic
CLI tools for manipulating the Mosyle MDM.

Version: 0.1.0
https://github.com/JCSmillie/MOSBasic
Usage: mosbasic [command]
Commands:
  lostmodeon			Give single asset tag.  Will enable lost mode with default message.
  lostmodeoff			Give single asset tag.  Will disable lost mode.
  annoy         		Give single asset tag.  Will play sound.  If device is not in lost mode
 				will also enable it.
  lostmodestatus  		Find out current Lost mode status of device.
  whoislost			Gives list of all devices currently in lost mode and waitng to be in
  			  	in lost mode.  Output is color coded and when ran ALL ENABLED DEVICES
				are sent the command to play sound.
  ioswipe			Give single asset tag.  Will Limbo and Wipe that iPad.
  				**NOTE** Wipe will fail if device is not on Wifi.
  ioswipe --scan		Scan multiple devices.  When done hit enter to give a blank.
  				All will be Limbo'd and wiped.  If an individual tag can't be found
				it will be skipped and logged.
  ioswipe --mass <FILE>		Give file with multiple tags.  One per line.  All will
            			be Limbo'd and wiped.  If an individual tag can't be found
		    		it will be skipped and logged.  <<PLANNED NOT YET READY>>
  iosdump			Dump info for all iOS devices from Mosyle to local reference files.
  macdump			Dump info for all MacOS devices from Mosyle to local reference files.
  userdump			Dump info for all Users in Mosyle to local reference files.
  iosassign			Info will be looked up and then device will be assigned.  <<REQUIRES USERLOOKUP MODULE>>
  iosassign --scan		Scan multiple devices  Tag first then assignment tag.  When done
  				hit enter to give a blank.  Info will be looked up and then device will
				be assigned.  <<REQUIRES USERLOOKUP MODULE>>
  iosassign --mass		Give file with multiple devices in form of ASSET TAG,USERNAME.  One
  				per line.  All will be assigned properly.  <<PLANNED NOT YET READY>> <<REQUIRES USERLOOKUP MODULE>>

  info <ASSET TAG/USERID/SERIAL>	Look up device assignment data by reference point  <ASSET TAG/USERID/SERIAL>
  listgroups --mac		Display list of all current Mac Device Groups in Mosyle
  listgroups --ios		Display list of all current iOS Device Groups in Mosyle

  serialcheck /path/to/textfileofserials.txt </output/place.csv>
  				This command takes a text file (one serial per line) and outputs
				what serials also appear in Mosyle from that file.  This is helpful
				for end of year operations where you want to release a ton of Macs
				or iPads.  Send the output to Mosyle support to have those all removed.
				Output file is optional.
 ```
 
How this stuff works will be detailed better in the Wiki but for example if you wanted to enable lost mode on a device you would:
 ```
    mosbasic lostmodeon 23692
 ```
At this point the tag would be queried against our cache'd data to get the UDID and then that UDID would be sent to the MoyleAPI to put the device in lost mode followed by playing a sound.  So now with the iPad in lost mode we can ask for more info:
 ```
    mosbasic lostmodestatus 23692
 ```
 Serial number is grabbed from our cached query data and then we ask the MosyleAPI about just this unit for more info and get:
 ```
	--------------------------------------------------
	UDID=000000000000abcdabcd00000000000
	DeviceSerialNumber=DMPXXXXX4JF8J
	TAGS=MSMSPool
	ASSET TAG=23692
	ENROLLMENT_TYPE=
	USERID=
	ASSIGNED TO=
    
	Last Seen (EPOCH)=1636578430
	Last Seen (Date)=2021-11-10 04:07:10 PM
	Last Seen (Hours Ago)=0
	Lost Mode Status=ENABLED
	Location Data=40.4294700623,-79.7585754395
    
	GO TO THIS LINK TO SEE LOST IPAD LOCATION-> https://maps.google.com/?q=40.4294700623,-79.7585754395
	--------------------------------------------------
 ```
If lost mode is enabled and location data is available we get it back and provide a hyper link to the location on Google Maps.  Now this iPad in the example is a Shared iPad so somet data is not noted, but you can see that had it been normally assigned we would have something there.

From here we can make the iPad play sound again:

    mosbasic annoy 23692
 
Or we can disable lost mode:

    mosbasic lostmodeoff 23692
 
The above example is just dealing with lost devices, but mosbasic can do more.  See the wiki.
 
## Prerequisites
ASOF 9/25/25 Machine where MOSBasic will be installed must have zsh, bash, perl, jq, and python3 available.
 
## Configuration
 To get started you need to use the _RUNME1st_CONFIGSCRIPT.sh_ to setup.  _RUNME1st_CONFIGSCRIPT.sh_ command will prompt you through the setup process of:
 * Save your Mosyle API key (to have a MosyleAPI key you must be a premium customer) to ~/.mosyleapikey
 * Detect where you have saved the github.
 * Link the _mosbasic_ command to _/usr/local/bin/mosbasic_
 * Enable IncidentIQ dependancies id desired.

Now run the _mosbasic_ command.  It will ensure everything else is in place and run a query for the first time to get a cache of your iOS devices and User accounts for local query.  This will happen any time these cached queries are not found in /tmp or the queried files are older than a day.

### A side note MOS
Its great that MOS makes me think of two things I love working on:
 * MOSyle
 * [MOS Technology](https:_en.wikipedia.org/wiki/MOS_Technology), Commodore's chip foundry out in West Chester, PA

## Module Support
MOSBasic supports external modules for lookup support.  When you run _RUNME1st_CONFIGSCRIPT.sh_ you will be asked if you want support for external modules.  Today the only supported options are: iiq, other, and none.
  * iiq-> IndcidentIQ support.  This also requires $LOCALCONF/.incidentIQ to exist.  You must create this file by hand.
  * other-> _NOT SUPPORTED TODAY BUT WILL BE_
  * none-> Do not use modules.  This will cripple some features of MOSBasic like assigning iPads unless you are inputting USERNAME and SERIAL.  If you are inputting student ID number or anything else you will need these look ups to do cross references.
  
  
### IIQ File Setup
The IIQ file must be setup as so:
 ```
apitoken="<<<YOUR KEY FROM INCIDENTIQ>>>"   
siteid="<<<YYOUR SITE ID FROM INCIDENT IQ>>>"
baseurl="<<<YYOUR BASE URL FROM INCIDENT IQ>>>"
 ```	
All of the above should be listed in ~/.incidentIQ

## Extras Folder
In this folder you will find scripts that rely on MOSBasic to do other functions. 
 - ShakeNBake_V3.sh <-This script is run with CFGUTIL (cfgutil exec -a ShakeNBake_V3.sh) to process iPads that are plugged into the Mac running the script.  It will try to use either local trust or MDM Erase to wipe the iPad, then make sure it has latest iPadOS, install a wifi profile, and push the iPad to DEP to finish.  More information can be seen in my PSU MacAdmins 2022 presentation.  
 
 I use **autoload is-at-least** in ShakeNBake to do compares on what Apple says a device should use and what the device has.  When cfgutil executes ShakeNBake though it doesn't call the Autoload command... It doesn't know what it is.  I know this has something to do with how cfgutil loads scripts and their support files but haven't put my finger on a good fix.  In the short term when launching ShakeNBake use this line instead-> `cfgutil exec -a 'zsh -c "/Users/Shared/ShakeNBake/ShakeNBake_V3.sh"'`  This will insure that all the shell files get loaded.  Also There is something weird with Ventura Beta (as of 7/14/22) and multiple iPads (more than 4) on a single bus.  I've seen this with my Thundersync unit.  Needs more testing and I'll report it.  For now run only in Monterey if you can.

#Nifty Beta Stuff 0.3.0.BETA - 9-25-25
Might be wondering why the version bump...  Well this is to accomodate the addition of a new set of data points MOSBasic can dump now - CLASSES.  Not only does it dump but I also put together a very basic proof of concept "Get Info for Classes" command.  I'm not sure what the future is yet on this, but I know I needed this support.  I explain better in the code comments themselves.
 
Another reason for the version bump is I'm moving away a tad from my first ideas of what MOSBasic should be in particular that it should only depend on whats available to it by default on any MacOS running machine.  In recent years Apple has anounced plans for the future sunset of including some shells and languages from their base distribution so I can't assume these things exist anymore.  I also have slowly been making code changes here and there to be more Linux friendly.. and Docker friendly.  As my other project Musky is heavily dependant on MOSBASIC as its backend one of my big ideas right now is a Musky/MOSBasic docker so that anyone can just edit 2 files and fire it up, go to town.  I DO have this working for Gateway SD today, but its not ready for public consumption yet.
 
One final note about the beta stuff.  There are a lot of "Additional Config" options I've added to MOSBasic through the year to get MUSKY off the ground that are not documented.  I will try to get that done before the next version. 
-JCS
 

# Disclaimer
While all of this stuff is used on a daily bases at Gateway School District in our persuit to best support the students there is always a chance for a bug to be found that doesn't effect me.  I'm not a master coder by any means but know enough to get myself into trouble... so don't be surprised if there is a better way to do things I'm not using.  As far as I'm aware there is nothing malacious in my code.  It only works on files created by itself and shouldn't hurt anything.  That being said end responsibility I take none and as my favorite AppleSE always said "Mileage may very" but I hope this does work for you.
 
 
