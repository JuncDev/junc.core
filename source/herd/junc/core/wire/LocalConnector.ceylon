import ceylon.collection {
	ArrayList,
	HashMap
}

import herd.junc.api {
	Junc,
	Promise,
	JuncService,
	InvalidServiceError,
	JuncSocket,
	Context,
	Connector,
	Workshop,
	ServiceAddress,
	Message,
	JuncTrack
}
import herd.junc.core.utils {
	ListItem,
	TwoWayList
}


"Container for local services and connections."
by( "Lis" )
class LocalConnector (
	"Context connector is executed on." JuncTrack track,
	"Selecting one service from a list when connection to be established." ServiceSelector selector,
	"_Junc_ the connector may use." Junc junc
)
	satisfies	Workshop<Anything, Anything, ServiceAddress>
				& Connector<Anything, Anything, ServiceAddress>
{
	
	abstract class ServiceStore( shared ConnectedJuncServiceAny service )
			extends ListItem<ServiceStore>()
	{
		shared formal void remove();
	}
	
	"Services registered under manager."
	HashMap<ServiceAddress, TwoWayList<ServiceStore>> services
			= HashMap<ServiceAddress, TwoWayList<ServiceStore>>();
	
	class ServiceStoreImpl( ConnectedJuncServiceAny service ) extends ServiceStore( service )
	{
		shared actual void remove() {
			registration.cancel();
			if ( exists list = services.get( service.address ) ) {
				if ( list.empty ) { services.remove( service.address ); }
			}
		}
	}
	
	
	"Adds service to storage and returns service wrapper - to correctly close service."
	void addService( ConnectedJuncServiceAny service ) {
		ServiceStore store = ServiceStoreImpl( service );
		if ( exists list = services.get( service.address ) ) {
			list.addToList( store );
		}
		else {
			TwoWayList<ServiceStore> list = TwoWayList<ServiceStore>();
			services.put( service.address, list );
			list.addToList( store );
		}
		service.onClose( store.remove );
	}

	
	"Returns service from store if it is asked type and not blocked."
	ConnectedJuncService<From, To>? filterStores<From, To>( ServiceStore store ) {
		if ( !store.service.blocked, is ConnectedJuncService<From, To> service = store.service ) {
			return service;
		}
		else {
			return null;
		}
	}
	
	"Returns all services meet address and type."
	ConnectedJuncService<From, To>[] notBlockedServiceByAddress<From, To>( ServiceAddress address ) {
		if ( exists list = services.get( address ) ) {
			ArrayList<ConnectedJuncService<From, To>> ret = ArrayList<ConnectedJuncService<From, To>>();
			list.forEachActiveMap<ConnectedJuncService<From, To>> (
				filterStores<From, To>, ret.add
			);
			return ret.sequence();
		}
		else { return []; }
	}
	
	
	shared actual Promise<Message<JuncService<Send, Receive>, Null>> provideService<Send, Receive> (
		ServiceAddress address, JuncTrack track
	)
			given Send of Anything
			given Receive of Anything	
	{
		value addedService = LocalService<Send, Receive>( address, track.context, junc );
		return track.context.resolvedPromise (
			this.track.createMessage<JuncService<Send, Receive>, Null> (
				addedService,
				( Message<Null, JuncService<Send, Receive>> msg ) {
					addService( addedService );
				}
			)
		);
	}
	
	shared actual Promise<JuncSocket<Send, Receive>> connect<Send, Receive> (
		ServiceAddress address, Context clientContext
	)
			given Send of Anything
			given Receive of Anything
	{
		if ( nonempty list = notBlockedServiceByAddress<Send, Receive>( address ) ) {
			return selector.select( list ).connect<Send, Receive>( clientContext );
		}
		else {
			return clientContext.rejectedPromise( InvalidServiceError() );
		}
	}
	
}
