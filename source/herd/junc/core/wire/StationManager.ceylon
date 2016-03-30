import ceylon.collection {
	ArrayList
}
import ceylon.language.meta {
	type
}

import herd.junc.api {
	Registration,
	Promise,
	JuncTrack,
	JuncSocket,
	JuncAddress,
	Station,
	Context,
	JuncService,
	Emitter,
	Publisher,
	Junc,
	LoadLevel,
	Timer,
	TimeRow,
	TimeEvent,
	Deferred,
	Workshop,
	Connector,
	ContextStoppedError,
	ServiceRegistrationError,
	InvalidServiceError,
	ConnectorDescriptor,
	WorkshopDescriptor,
	JuncEvent,
	Message,
	JuncStoppedError
}
import herd.junc.api.monitor {
	Monitor,
	Counter,
	monitored
}
import herd.junc.core.concurrency {
	ProcessorFactory,
	currentContext,
	Processor
}

import java.lang {
	Runnable
}
import java.util.concurrent.atomic {

	AtomicBoolean
}


"Manages stations."
by( "Lis" )
shared class StationManager (
	"Creates new processors." ProcessorFactory processorFactory,
	"Monitor may be used for log and monitoring." Monitor monitor,
	"Number of messages stored while not listener added." Integer numberOfStoredMessages
) {

	"Stations number."
	Counter numberOfStations = monitor.counter( monitored.numberOfStations );
	
	"Events."
	EmitterPublisher<JuncEvent> events = EmitterPublisher<JuncEvent>( currentContext, 0 ); 
	
	"`True` if running and `false` if stopped."
	AtomicBoolean runningAtomic = AtomicBoolean( true );
	
	"`True` if running and `false` if stopped."
	shared Boolean running => runningAtomic.get();
	

// stations within the manager

	void closeStation( StationRegister station ) => station.stationRegistration.cancel();
	
	"Stations which run on this manager."
	StationContainer stationContainer = StationContainer();
	
		
	"Creates only track."
	JuncTrack juncTrack( "Back register." StationRegister register ) {
		return object satisfies JuncTrack {
			Processor processor = processorFactory.createProcessor();
			TrackHelper track = TrackHelper( processor );
			register.addTrack( track );

			EmitterPublisher<JuncEvent> eventsOnTrack = EmitterPublisher<JuncEvent>( processor, 0 );
			value eventsReg = events.addProxy( eventsOnTrack.publisher );
			
			shared actual Emitter<JuncEvent> juncEvents = eventsOnTrack.emitter;

			shared actual Context context => processor;
			
			shared actual Boolean closed => !processor.running;
			
			shared actual LoadLevel loadLevel => processor.loadLevel;
			
			shared actual Timer createTimer( TimeRow timeRow ) {
				EmitterPublisher<TimeEvent> timeMessanger = EmitterPublisher<TimeEvent>( processor, 0 );
				return processor.createTimer( timeMessanger.emitter, timeMessanger.publisher, timeRow );
			}
			
			shared actual Message<Body, Reply> createMessage<Body, Reply> (
				Body body,
				Anything(Message<Reply, Body>)? replyHandler,
				Anything(Throwable)? rejectHandler
			) => MessageImpl( context, body, replyHandler, rejectHandler );
			
			
			shared actual void close() {
				eventsReg.cancel();
				track.close();
				register.trackClosed(); // close register if no more tracks
			}
			
			shared actual Promise<JuncSocket<FromService, ToService>> connect<FromService, ToService, Address> (
				Address address
			)	given Address satisfies JuncAddress
					=> 	if ( closed )
					then currentContext.rejectedPromise( ContextStoppedError() )
					else outer.connect<FromService, ToService, Address>( address, processor )
							.onComplete( track.addSocket );
			
			shared actual Promise<JuncService<FromService, ToService>> registerService<FromService, ToService, Address> (
				Address address
			)	given Address satisfies JuncAddress
					=>	if ( closed )
					then currentContext.rejectedPromise( ContextStoppedError() )
					else outer.registerService<FromService, ToService, Address>( address, processor )
						.onComplete( track.storeService );
			
			shared actual Promise<Registration> registerConnector<From, To, Address> (
				Connector<From, To, Address> connector
			) 		given Address satisfies JuncAddress
					=>	if ( closed )
						then currentContext.rejectedPromise( ContextStoppedError() )
						else register.addConnector( connector, processor );
			
			shared actual Promise<Registration> registerWorkshop<From, To, Address> (
				Workshop<From, To, Address> workshop
			)		given Address satisfies JuncAddress
					=>	if ( closed )
						then currentContext.rejectedPromise( ContextStoppedError() )
						else register.addWorkshop( workshop, processor );
			
			shared actual Promise<Result> executeBlocked<Result>( Result() exec ) {
				if ( closed ) {
					return currentContext.rejectedPromise( ContextStoppedError() );
				}
				else {
					Deferred<Result> def = processor.newResolver<Result>();
					processorFactory.executeBlocked (
						object satisfies Runnable {
							shared actual void run() {
								try { def.resolve( exec() ); }
								catch ( Throwable err ) { def.reject( err ); }
							}
						}
					);
					return def.promise;
				}
			}
			
		};
	}
	
	
	"_Junc_ backgrounded by [[register]]."
	Junc juncForRegister( "Back register." StationRegister register ) {
		return object satisfies Junc {
			
			shared actual JuncTrack newTrack()
					=>	if ( register.closed ) then closedTrack else juncTrack( register );
			
			shared actual Promise<Registration> deployStation( Station station, Context? responseContext )
					=> outer.deployStation( station, responseContext );
			
			
			shared actual [JuncSocket<From,To>, JuncSocket<To,From>] socketPair<From, To>( Context first, Context second )
					=> LocalSocketPair<From, To>( first, second, numberOfStoredMessages ).pair;
			
			shared actual [Emitter<Item>, Publisher<Item>] messanger<Item>( Context context ) {
				EmitterPublisher<Item> ret = EmitterPublisher<Item>( context, 0 );
				return [ret.emitter, ret.publisher];
			}
			
			shared actual Monitor monitor => register.monitor;
			shared actual Boolean overloaded => processorFactory.overloaded;			
			
			shared actual ConnectorDescriptor<From, To, Address>[] registeredConnectors<From, To, Address>()
					given Address satisfies JuncAddress
			{
				ArrayList<ConnectorDescriptor<From, To, Address>> ret = ArrayList<ConnectorDescriptor<From, To, Address>>();
				stationContainer.stations.forEachActive (
					( StationRegister register ) {
						ret.addAll( register.registeredConnectors<From, To, Address>() );
					}
				);
				return ret.sequence();
			}
			
			shared actual WorkshopDescriptor<From, To, Address>[] registeredWorkshops<From, To, Address>()
					given Address satisfies JuncAddress
			{
				ArrayList<WorkshopDescriptor<From, To, Address>> ret = ArrayList<WorkshopDescriptor<From, To, Address>>();
				stationContainer.stations.forEachActive (
					( StationRegister register ) {
						ret.addAll( register.registeredWorkshops<From, To, Address>() );
					}
				);
				return ret.sequence();
			}
			
		};
	}
	
	
	"Deployes station. Returns `promise` resolved with station registration or rejected if some error occured."
	shared Promise<Registration> deployStation (
		"Station to be deployed." Station station,
		"Optional context returned `promise` has to work on." Context? responseContext )
	{
		if ( running ) {
			StationRegister register = StationRegister( station, monitor, stationContainer, events.publisher );
			value track = juncTrack( register );
			value junc = juncForRegister( register );
			value ret = track.context.executeWithPromise<Anything, Null> (
					( Null n ) => station.start( track, junc ), null
				).map<Registration> (
						register.getStationRegistration
		 			).onComplete(
						( Registration reg ) {
							stationContainer.stations.addToList( register );
							numberOfStations.increment();
							monitor.logInfo( monitored.core, "station ```type( station )``` has been successfully deployed" );
						},
						( Throwable err ) {
							track.close();
							monitor.logError( monitored.core, "when deploying station ```type( station )```", err );
						}
					);
			return if ( exists resp = responseContext ) then ret.contexting( resp ) else ret;
		}
		else {
			return currentContext.rejectedPromise( JuncStoppedError() );
		}
	}
	
	
	"Establishes connection to serice with given address."
	Promise<JuncSocket<From, To>> connect<From, To, Address> (
		"Address to connect to." Address address,
		"Context client connection has to work on." Context clientContext
	)
			given Address satisfies JuncAddress
	{
		if ( running ) {
			if ( exists con = stationContainer.getConnector<From, To, Address>() ) {
				return con.connect<From, To>( address, clientContext );
			}
			else {
				return clientContext.rejectedPromise( InvalidServiceError() );
			}
		}
		else {
			return currentContext.rejectedPromise( JuncStoppedError() );
		}
	}
	
	
	"Registers service with given address, data types and work context."
	Promise<JuncService<From, To>> registerService<From, To, Address> (
		"Address service listen to." Address address,
		"Context service has to work on." Context context
	)
			given Address satisfies JuncAddress
	{
		if ( running ) {
			if ( exists work = stationContainer.getWorkshop<From, To, Address>() ) {
				return work.provideService<From, To>( address, context );
			}
			else {
				value err = ServiceRegistrationError();
				monitor.logError (
					monitored.core,
					"tries to register service with unsupported address ```address```",
					err
				);
				return context.rejectedPromise( err );
			}
		}
		else {
			return currentContext.rejectedPromise( JuncStoppedError() );
		}
	}
	
	
	"Stops all stations and subsequent connections, services, workshops and connectors."
	shared void stop() {
		if ( runningAtomic.compareAndSet( true, false ) ) {
			monitor.removeCounter( monitored.numberOfStations );
			stationContainer.stations.forEachActive( closeStation );
		}
	}
	
}
