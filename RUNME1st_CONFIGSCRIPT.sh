#!/bin/zsh

if [ ! -h "/usr/local/bin/mosbasic" ]; then
	BAGCLI_WORKDIR=$(cd $(dirname $0) && pwd)
	echo "Setting up linkage from $BAGCLI_WORKDIR/mosbasic to /usr/local/bin/mosbasic"
	ln -s $BAGCLI_WORKDIR/mosbasic /usr/local/bin/mosbasic

else
	BAGCLI_WORKDIR=$(readlink /usr/local/bin/mosbasic)
	#Remove our command name from the output above
	BAGCLI_WORKDIR=${BAGCLI_WORKDIR//mosbasic/}
	echo "Link to /usr/local/bin/mosbasic appears to be setup."
fi

#Load our common modules
. "$BAGCLI_WORKDIR/common"



rm -Rf $BAGCLI_WORKDIR/config

#Make sure we can find out config file...
if [ ! -f "$BAGCLI_WORKDIR/config" ] ; then
	echo "ERROR: No $BAGCLI_WORKDIR/config file not found. MAKING."
	echo "Will store config files in $HOME"

	echo "#MOSBasic  " > $BAGCLI_WORKDIR/config
	echo "# " >> $BAGCLI_WORKDIR/config
	echo "#   __  __  ____   _____ ____            _  " >> $BAGCLI_WORKDIR/config
	echo "#  |  \/  |/ __ \ / ____|  _ \          (_) " >> $BAGCLI_WORKDIR/config
	echo "#  | \  / | |  | | (___ | |_) | __ _ ___ _  ___ " >> $BAGCLI_WORKDIR/config
	echo "#  | |\/| | |  | |\___ \|  _ < / _\` / __| |/ __| " >> $BAGCLI_WORKDIR/config
	echo "#  | |  | | |__| |____) | |_) | (_| \__ \ | (__ " >> $BAGCLI_WORKDIR/config
	echo "#  |_|  |_|\____/|_____/|____/ \__,_|___/_|\___| " >> $BAGCLI_WORKDIR/config
	echo "# " >> $BAGCLI_WORKDIR/config
	echo "# " >> $BAGCLI_WORKDIR/config
	echo " "  >> $BAGCLI_WORKDIR/config
	echo "#Common Variables " >> $BAGCLI_WORKDIR/config
	echo "LOCALCONF=\"$HOME\"	#Where your local config files are " >> $BAGCLI_WORKDIR/config 
	echo 'LOG="$LOCALCONF/MOSBasic/actions.log"	#Where Logs are kept ' >> $BAGCLI_WORKDIR/config 
	echo " "  >> $BAGCLI_WORKDIR/config
	echo "###EXTERNAL MODULES SUPPORT " >> $BAGCLI_WORKDIR/config
	echo "#This support is for external support systems which " >> $BAGCLI_WORKDIR/config
	echo "#can help to do outside lookups of things like usernames, " >> $BAGCLI_WORKDIR/config
	echo "#open tickets, make tickets, etc.  Read the README in " >> $BAGCLI_WORKDIR/config
	echo "#the modules directory for more info.  By default this " >> $BAGCLI_WORKDIR/config
	echo "#is all disabled.  Uncomment the support you want. " >> $BAGCLI_WORKDIR/config
	echo '#source "$BAGCLI_WORKDIR/modules/Default.sh" ' >> $BAGCLI_WORKDIR/config
	echo " "  >> $BAGCLI_WORKDIR/config
	
	
	#SHOW THE USER - ASKING ABOUT EXTERNAL MODULE SUPPORT
	echo "###EXTERNAL MODULES SUPPORT "
	echo "#This support is for external support systems which " 
	echo "#can help to do outside lookups of things like usernames, " 
	echo "#open tickets, make tickets, etc.  Read the README in "
	echo "#the modules directory for more info.  By default this " 
	echo "#is all disabled. "
	echo " "
	echo "Would you like to enable External Module for IncidentIQ Support <Y/N>"
	read WeWantIIQ
	
	if [ "$WeWantIIQ" = "Y" ] || [ "$WeWantIIQ" = "y" ]; then
		echo "Enabling IncidentIQ Support"
		echo "#IncidentIQ support " >> $BAGCLI_WORKDIR/config
		echo 'source "$BAGCLI_WORKDIR/modules/incidentiq.sh" ' >> $BAGCLI_WORKDIR/config
		echo "GotModules=iiq" > "$LOCALCONF/MOSBasic/.modules"
		echo " "  >> $BAGCLI_WORKDIR/config
		echo '#source "$BAGCLI_WORKDIR/modules/Default.sh" ' >> $BAGCLI_WORKDIR/config
		
	else
		echo "Setting Default value"		
		echo "##IncidentIQ support " >> $BAGCLI_WORKDIR/config
		echo '#source "$BAGCLI_WORKDIR/modules/incidentiq.sh" ' >> $BAGCLI_WORKDIR/config
		echo "GotModules=none" > "$LOCALCONF/MOSBasic/.modules"
		echo " "  >> $BAGCLI_WORKDIR/config
		echo 'source "$BAGCLI_WORKDIR/modules/Default.sh" ' >> $BAGCLI_WORKDIR/config
	fi

	#Add our defaults to the config file/
	cat $BAGCLI_WORKDIR/config.BASE >> $BAGCLI_WORKDIR/config
  
  


else 
	source "$BAGCLI_WORKDIR/config"
	
	echo "All hidden files (like .MosyleAPI for your API key) will be kept in $LOCALCONF"
	echo "All logs will be kept in $LOG"
fi
