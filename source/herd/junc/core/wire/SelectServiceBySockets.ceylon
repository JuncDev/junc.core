
"Selects service with min number of sockets from the list."
by( "Lis" )
shared class SelectServiceBySockets() satisfies ServiceSelector
{
	
	shared actual ConnectedJuncService<FromService, ToService> select<FromService, ToService> (
		[ConnectedJuncService<FromService, ToService>+] list
	) {
		variable ConnectedJuncService<FromService, ToService> ret = list.first;
		variable Integer min = ret.numberOfSockets;
		for ( item in list ) {
			if ( item.numberOfSockets < min ) {
				min = item.numberOfSockets;
				ret = item;
			}
		}
		return ret;
	}
	
}
