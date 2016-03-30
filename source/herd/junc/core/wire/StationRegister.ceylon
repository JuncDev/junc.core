import herd.junc.core.utils {

	ListBody,
	DualList,
	ListItem,
	TwoWayList
}
import herd.junc.api {

	WorkshopRegistrationError,
	Context,
	Promise,
	Station,
	ConnectorRegistrationError,
	Registration,
	JuncAddress,
	ContextStoppedError,
	Workshop,
	Connector,
	WorkshopDescriptor,
	ConnectorDescriptor,
	JuncEvent,
	Publisher,
	ConnectorAddedEvent,
	WorkshopAddedEvent,
	ServiceDescriptor
}
import herd.junc.api.monitor {

	monitored,
	Monitor
}
import java.util.concurrent.atomic {

	AtomicBoolean
}
import herd.junc.core.metric {

	MonitorRef
}
import ceylon.collection {

	ArrayList
}


"Represents station which works on junc."
class StationRegister (
	"Station runs within this register." shared Station station,
	"Monitor can be used for log and monitoring." Monitor monitorBase,
	"Storage of workshops and connectors." ProviderSearcher providers,
	"Publish junc events to." Publisher<JuncEvent> events
)
		extends ListItem<StationRegister>()
		satisfies ProviderSearcher
{
	
	"Monitor reference - allows remove all items registered by station."
	shared MonitorRef monitor = MonitorRef( monitorBase );
	
	"Closed or running."
	AtomicBoolean closedAtomic = AtomicBoolean( false );
	shared Boolean closed => closedAtomic.get();
	
	"Tracks behind this station."
	TwoWayList<TrackHelper> tracks = TwoWayList<TrackHelper>();
	
	"Workshops registered within this station."
	DualList<WorkshopAny> stationWorkshops = DualList<WorkshopAny>();
	
	"Connectors registered within this station."
	DualList<ConnectorAny> stationConnectors = DualList<ConnectorAny>();
	
	"Closes workshop."
	void closeWorkshop( ListBody<WorkshopAny> workshop ) => workshop.body.close();
	
	"Closes connector."
	void closeConnector( ListBody<ConnectorAny> connector ) => connector.body.close();
	
	"Closes track."
	void closeTrack( TrackHelper cont ) => cont.close();
	
	
	shared actual ConnectorAbs<From, To, Address>? getConnector<From, To, Address>( )
			given Address satisfies JuncAddress
	{
		variable ConnectorAbs<From, To, Address>? retValue = null;
		stationConnectors.lock();
		variable ListBody<ConnectorAny>? h = stationConnectors.head;
		while ( exists n = h ) {
			if ( is ConnectorAbs<From, To, Address> ret = n.body ) {
				retValue = ret;
				break;
			}
			h = n.next;
		}
		stationConnectors.unlock();
		return retValue;
	}
	
	shared actual WorkshopAbs<From, To, Address>? getWorkshop<From, To, Address>()
			given Address satisfies JuncAddress
	{
		variable WorkshopAbs<From, To, Address>? retValue = null;
		stationWorkshops.lock();
		variable ListBody<WorkshopAny>? h = stationWorkshops.head;
		while ( exists n = h ) {
			if ( is WorkshopAbs<From, To, Address> ret = n.body ) {
				retValue = ret;
				break;
			}
			h = n.next;
		}
		stationWorkshops.unlock();
		return retValue;
	}
	
	
	shared ConnectorDescriptor<From, To, Address>[] registeredConnectors<From, To, Address>()
			given Address satisfies JuncAddress
	{
		ArrayList<ConnectorDescriptor<From, To, Address>> ret = ArrayList<ConnectorDescriptor<From, To, Address>>();
		stationConnectors.forEachActive (
			( ListBody<ConnectorAny> con ) {
				if ( is ConnectorAbs<From, To, Address> abs = con.body ) {
					ret.add( abs.descriptor );
				}
			}
		);
		return ret.sequence();
	}
	
	shared WorkshopDescriptor<From, To, Address>[] registeredWorkshops<From, To, Address>()
			given Address satisfies JuncAddress
	{
		ArrayList<WorkshopDescriptor<From, To, Address>> ret = ArrayList<WorkshopDescriptor<From, To, Address>>();
		stationWorkshops.forEachActive (
			( ListBody<WorkshopAny> con ) {
				if ( is WorkshopAbs<From, To, Address> abs = con.body ) {
					ret.add( abs.descriptor );
				}
			}
		);
		return ret.sequence();
	}
	
	
	"Removes station if no more tracks."
	shared void trackClosed() {
		if ( tracks.empty ) { stationRegistration.cancel(); }
	}
	
	"Adds new track to this register."
	shared void addTrack( "Track to be added." TrackHelper track ) {
		if ( closed ) { track.close(); }
		else { tracks.addToList( track ); }
	}
	
	"Adds new connector.  Returns promise on `connectorContext` resolved with registration to cancel this connector."
	shared Promise<Registration> addConnector<From, To, Address> (
		Connector<From, To, Address> connector, Context connectorContext
	)
			given Address satisfies JuncAddress
	{
		if ( !closed ) {
			if ( exists con = providers.getConnector<From, To, Address>() ) {
				monitor.logWarn( monitored.core, "trying to register connector which has been already registered" );
				return connectorContext.rejectedPromise( ConnectorRegistrationError() );
			}
			else {
				ConnectorImpl<From, To, Address> term = ConnectorImpl<From, To, Address> (
					connector, connectorContext, events
				);
				Registration reg = stationConnectors.addItem( term );
				events.publish( ConnectorAddedEvent( term.descriptor ) );
				return connectorContext.resolvedPromise<Registration> (
					object satisfies Registration {
						shared actual void cancel() {
							reg.cancel();
							term.close();
						}
					}
				);
			}
		}
		else {
			monitor.logError( monitored.core, "tries to register connector using closed station" );
			return connectorContext.rejectedPromise( ContextStoppedError() );
		}
	}
	
	"Adds new workshop.  
	 Returns promise on `workshopContext` resolved with registration to cancel added workshop."
	shared Promise<Registration> addWorkshop<From, To, Address> (
		Workshop<From, To, Address> workshop,
		Context workshopContext
	)
			given Address satisfies JuncAddress
	{
		if ( !closed ) {
			if ( exists w = providers.getWorkshop<From, To, Address>() ) {
				monitor.logWarn( monitored.core, "tries to register workshop which has been already registered" );
				return workshopContext.rejectedPromise( WorkshopRegistrationError() );
			}
			else {
				WorkshopImpl<From, To, Address> term = WorkshopImpl<From, To, Address> (
					workshop, workshopContext, events, monitor
				);
				Registration reg = stationWorkshops.addItem( term );
				events.publish (
					WorkshopAddedEvent<From, To, Address> (
						object satisfies WorkshopDescriptor<From, To, Address> {
							shared actual {ServiceDescriptor<Send, Receive>*} services<Send, Receive>()
									given Send satisfies From
									given Receive satisfies To
									=> {};
						}
					)
				);
				return workshopContext.resolvedPromise<Registration> (
					object satisfies Registration {
						shared actual void cancel() {
							reg.cancel();
							term.close();
						}
					}
				);
			}
		}
		else {
			monitor.logError( monitored.core, "tries to register workshop using closed station" );
			return workshopContext.rejectedPromise( ContextStoppedError() );
		}
	}
	
	"Closes this station register and all subsequent workshops and connectors."
	shared object stationRegistration satisfies Registration {
		shared actual void cancel() {
			if ( closedAtomic.compareAndSet( false, true ) ) {
				// remove from station list
				registration.cancel();
				// close workshops
				stationWorkshops.forEachActive( closeWorkshop );
				stationWorkshops.clear();
				// close connectors
				stationConnectors.forEachActive( closeConnector );
				stationConnectors.clear();
				// close tracks
				tracks.forEachActive( closeTrack );
				tracks.clear();
				// decrement number of stations
				monitor.counter( monitored.numberOfStations ).decrement();
				// remove all monitored values
				monitor.clear();
			}
		}
	}
	
	shared Registration getStationRegistration( Anything val ) { return stationRegistration; }
	
}
