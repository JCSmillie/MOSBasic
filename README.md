# MOSBasic

___  ________ ___________           _      <br />
|  \/  |  _  /  ___| ___ \         (_)     <br />
| .  . | | | \ `--.| |_/ / __ _ ___ _  ___ <br />
| |\/| | | | |`--. \ ___ \/ _` / __| |/ __|<br />
| |  | \ \_/ /\__/ / |_/ / (_| \__ \ | (__ <br />
\_|  |_/\___/\____/\____/ \__,_|___/_|\___|<br />


Easy to use command line tools for interacting with MOSYLE MDM.  In places I also will interact with IncidentIQ ticket system for data.  I'm going to try to run my inventory check module so anyone could easily write their own module for the ticket system they use.  Will post a note about that in the wiki later when we get there.  This command was built for daily use at Gateway School District so we could easily maniplulate devices without having to go to the GUI every time.  It is 
 
 **NOTE** These commands rely on asset tags for reference.  
 
 My goal here is to try to create some simple command line tools which can let admins quickly do common tasks from the CLI.  Tasks like:
 * Work with tags (add, remove, remove all)
 * Work with Lost Mode (enable, disable, play sound)
 * Compare assignment of device Mosyle vs. IncidentIQ
 * Assign devices single, masss (scan from the command line,) or by file
 * Deassign device (send to Limbo) single, masss (scan from the command line,) or by file
 * Wipe device (requires device to have recently checked in)
 
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
 https:_github.com/JCSmillie/MOSBasic
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
   iosdump			Dump info for all iOS devices from Mosyle
   				to local reference files.
   userdump			Dump info for all Users in Mosyle to local
 				reference files.
   iosassign			Info will be looked up and then device will be assigned.  <<REQUIRES USERLOOKUP MODULE>>
   iosassign --scan		Scan multiple devices  Tag first then assignment tag.  When done
   				hit enter to give a blank.  Info will be looked up and then device will
 				be assigned.  <<REQUIRES USERLOOKUP MODULE>>
   iosassign --mass		Give file with multiple devices in form of ASSET TAG,USERNAME.  One
   				per line.  All will be assigned properly.  <<PLANNED NOT YET READY>> <<REQUIRES USERLOOKUP MODULE>>

   info <ASSET TAG/USERID/SERIAL>	Look up device assignment data by reference point  <ASSET TAG/USERID/SERIAL>
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
 
 
