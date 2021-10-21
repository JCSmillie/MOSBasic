#MOSBasic/Modules README

The idea here is that anyone can write a plugable module which will answer the following commands when queried:
  *USERLOOKUP -> Give it a single arguement and return the following fields:
	  *Username
	  *FirstName
	  *LastName
	  *SchoolIdNumber
	  *Grade
	  *Homeroom
	  *LocationName
  
  *DEVICELOOKUP-> Give single argument (serial/tag) and return the following fields:
  	*Serial
	*Asset Tag
	*Make/Model
	*Status (Lost, Stolen, InService, InStorage)
  
TICKETLOOKUP-> Give a serial or tag and returns a ticket number if one exists.
SUBMITTICKET-> Give serial number and a ticket is made in whatever ticket system you support.

INVENTORYASSSIGNDEVICE-> Give serial number and user to assign and inventory system is updated
INVENTORYUNASSIGNDEVICE> Give serial number and device is unassign and inventory system is updated

**Take a look in MOSBasic/Modules/Default.sh to see what is expected to be returned by variables.**

MOSBasic can be used without these things.. though some functionality will be disabled.