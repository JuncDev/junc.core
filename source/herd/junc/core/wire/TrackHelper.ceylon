import ceylon.collection {
	HashMap
}

import herd.junc.api {
	JuncAddress
}
import herd.junc.core.concurrency {
	Processor
}
import herd.junc.core.utils {
	ListItem,
	DualList,
	ListBody,
	TwoWayList
}


"Helps track organization - contains services and connections work on track.  
 Non thread safe - to be called from a `processor`."
by( "Lis" )
class TrackHelper (
	"Processor backed to this track." Processor processor
)
	extends ListItem<TrackHelper>()
{
	
	abstract class ServiceStoreAbs( shared JuncServiceAny service ) extends ListItem<ServiceStoreAbs>() {
		shared formal void remove();
	}
	
	"Services registered under track."
	HashMap<JuncAddress, TwoWayList<ServiceStoreAbs>> services = HashMap<JuncAddress, TwoWayList<ServiceStoreAbs>>();
	
	class ServiceStore( JuncServiceAny service ) extends ServiceStoreAbs( service ) {
		shared actual void remove() {
			registration.cancel();
			if ( exists list = services.get( service.address ), list.empty ) {
				services.remove( service.address );
			}
		}
	}
	

	"Sockets connected via this track to some remote address."
	DualList<JuncSocketAny> sockets = DualList<JuncSocketAny>();

	"Closes socket."
	void closeSocket( ListBody<JuncSocketAny> socket ) => socket.body.close(); 
	
	"Adds socket to the total list."
	shared void addSocket( JuncSocketAny socket ) => socket.onClose( sockets.addItem( socket ).cancel );
	
	"Closing service."
	void closeService( ServiceStoreAbs service ) => service.service.close(); 
	
	"Performs closing - to be called on backed track."
	void doClose() {
		if ( processor.running ) {
			// close sockets
			sockets.forEachActive( closeSocket );
			sockets.clear();
			// close services
			for ( serviceList in services.items ) {
				serviceList.forEachActive( closeService );
				serviceList.clear();
			}
			services.clear();
			// close processor
			processor.close();
		}
	}

	
	"Stores service into map - returns stored service."
	shared void storeService( JuncServiceAny service ) {
		if ( !service.closed ) {
			TwoWayList<ServiceStoreAbs> list;
			if ( exists l = services.get( service.address ) ) {
				list = l;
			}
			else {
				list = TwoWayList<ServiceStoreAbs>();
				services.put( service.address, list );
			}
			value store = ServiceStore( service );
			list.addToList( store );
			service.onClose( store.remove );
		} 
	}
	
	"Closes this track and all subsequent services and connections."
	shared void close() {
		registration.cancel();
		processor.execute( doClose );
	}
	
}
