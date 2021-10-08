# MOSBasic

___  ________ ___________           _      
|  \/  |  _  /  ___| ___ \         (_)     
| .  . | | | \ `--.| |_/ / __ _ ___ _  ___ 
| |\/| | | | |`--. \ ___ \/ _` / __| |/ __|
| |  | \ \_/ /\__/ / |_/ / (_| \__ \ | (__ 
\_|  |_/\___/\____/\____/ \__,_|___/_|\___|


 Easy to use command line tools for interacting with MOSYLE MDM.  In places I also will interact with IncidentIQ ticket system for data.  I'm going to try to run my inventory check module so anyone could easily write their own module for the ticket system they use.  Will post a note about that in the wiki later when we get there.
 
 **NOTE** These commands rely on asset tags for reference.  
 
 My goal here is to try to create some simple command line tools which can let admins quickly do common tasks from the CLI.  Tasks like:
 * Work with tags (add, remove, remove all)
 * Work with Lost Mode (enable, disable, play sound)
 * Compare assignment of device Mosyle vs. IncidentIQ
 * Assign devices single, masss (scan from the command line,) or by file
 * Deassign device (send to Limbo) single, masss (scan from the command line,) or by file
 * Wipe device (requires device to have recently checked in)
 
 # Shake N' Bake Script
 Part of this is also a cfgutil (Apple Configurator 2 command line) script which I call Shake N' Bake.  This script does the following:
 * Reset iPad...  Erase iPads which are pairable (by trusted cert) or do full restore.  
 * Reaches out to Mosyle to ensure the device is unassigned, removes lost mode, and clears any back commands waiting to process.
 * Installs Wifi Certificate
 * Setups up iPad through DEP.  If ipad is part of a Shared group then it will finish to that state.  
 
 Right now I use Shake N' Bake for day to day turning of devices from students who've gone so they are back in a hand out state.  
 
 **NOTE** As of today 9/26/2021 the Big Sur version of cfgutil has a flaw that it can't wipe iPads that are not pairable.  These devices must be booted into factory restore mode so it can work on them.  This has been reported to Apple and hoping for a fix soon.
 
 ## Why Shake N' Bake vs by hand
 By hand I have to:
 * Open up Mosyle website to disable lost mode if its enabled, clear back commands, and send device to Limbo.  IF the device is still on Wifi it will wipe at this point.  Otherwise we now need to factory mode the device and then use the Apple Configurator 2 GUI to wipe the device.
 * Manually take the iPad through setup screens to join a network
 * Finish tapping through.
 
 Nothing wrong with the above method.. but when I want to do a dozen of these things the script lets me set it, go do something else, and when I think about this again they are ready to go.
 
 ## Configuration
 To get started you need to use the //mosbasic// to setup the line.  MOSBasic command will prompt you through the setup process of:
 * Save your Mosyle API key (to have a MosyleAPI key you must be a premium customer) to ~/.mosyleapikey
 * Detect where you have saved the github.
 * Link the MOSYLEBasic command file to either your ~/.bashrc or ~/.zshrc
 * Enable IncidentIQ dependancies.
 * Setup Data gather script to run regularly and cache a copy of all of your devices assigned in Mosyle locally for quick access.
 
 
 
 
 ### A side note MOS
 Its great that MOS makes me think of two things I love working on:
 * MOSyle
 * [MOS](https://en.wikipedia.org/wiki/MOS_Technology), Commodore's chip foundry out in West Chester, PA


#Setup
To setup MOSBasic you need to do the following things:
  *Copy config.template to config
  *Edit config and change whats necessary.  For most people you will just change the LOCALCONF variable.
  *Run the mosbasic command.  It will detect and fix from there.
  
  
  
##Module Support
MOSBasic supports external modules for lookup support.  When you run SETUP you will be asked if you want support for external modules.  Today the only supported options are: iiq, other, and none.
  *iiq-> IndcidentIQ support.  This also requires $LOCALCONF/.incidentIQ to exist.  You must create this file by hand.
  *other-> <<NOT SUPPORTED TODAY BUT WILL BE>>
  *none-> Do not use modules.  This will cripple some features of MOSBasic like assigning iPads unless you are inputting USERNAME and SERIAL.  If you are inputting student ID number or anything else you will need these look ups to do cross references.
  
  
###IIQ File Setup
The IIQ file must be setup as so:
apitoken="<<<YOUR KEY FROM INCIDENTIQ>>>"   
siteid="<<<YYOUR SITE ID FROM INCIDENT IQ>>>"
baseurl="<<<YYOUR BASE URL FROM INCIDENT IQ>>>"
	
All of the above should be listed in $LOCALCONF/.incidentIQ
 
 