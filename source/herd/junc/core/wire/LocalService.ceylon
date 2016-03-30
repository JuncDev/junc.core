import herd.junc.api {
	ServiceAddress,
	JuncSocket,
	Promise,
	Emitter,
	Context,
	Junc,
	ServiceBlockedError,
	ServiceClosedError,
	Registration
}
import herd.junc.api.monitor {
	Counter,
	Meter,
	monitored
}
import herd.junc.core.utils {
	DualList,
	ListBody
}

import java.util.concurrent.atomic {
	AtomicBoolean
}


"Local service register - creates [[EmitterPublisher]] pair when connected."
by( "Lis" )
class LocalService<From, To> (
	"Address service listens to." shared actual ServiceAddress address,
	"Context the service operates." Context context,
	"_Junc_ the service utilizes." Junc junc
)
	satisfies ConnectedJuncService<From, To>
{
	
	"Number of sockets."
	Counter socketsNum = junc.monitor.counter( address.string + monitored.delimiter + monitored.numberOfSockets );
	"Service connection rate."
	Meter connectionRate = junc.monitor.meter( address.string + monitored.delimiter + monitored.connectionRate );
	
	
	"Sockets connected to this service."
	DualList<JuncSocketAny> sockets = DualList<JuncSocketAny>();
	
	EmitterPublisher<JuncSocket<To, From>> messanger
			= EmitterPublisher<JuncSocket<To, From>>( context, 0 );

	"Emitting lifecycle events of this service."
	Emitter<JuncSocket<To, From>> slot = messanger.emitter;
	
	"Is service closed."
	AtomicBoolean atomicClosed = AtomicBoolean(false );
	shared actual Boolean closed => atomicClosed.get();
	
	
	"Service blocking - avoiding connecting and registering services."
	AtomicBoolean atomicBlock = AtomicBoolean( false );
	shared actual Boolean blocked => atomicBlock.get();
	assign blocked => atomicBlock.set( blocked );
	
	shared actual Integer numberOfSockets => sockets.size;
	
	
	
	shared actual Registration onConnected<Receive, Send>( void connected( JuncSocket<Receive, Send> socket ) )
			given Receive satisfies To
			given Send satisfies From => slot.onData( connected );
	
	shared actual Registration onError( void error( Throwable err ) )  => slot.onError( error );
	
	shared actual Registration onClose( void close() ) => slot.onClose( close );
	
	
	"Socket has been removed - notifies empty if no more sockets.  
	 Not called when register is closed."
	void socketRemoved() => socketsNum.decrement();
	
	"Closes socket."
	void closeSocket( ListBody<JuncSocketAny> socket ) => socket.body.close(); 
	
	"Adds socket to the service."
	void addSocket( JuncSocketAny socket ) {
		socketsNum.increment();
		connectionRate.tick();
		socket.onClose( sockets.addItem( socket ).cancel );
		socket.onClose( socketRemoved );
	}
	
	
	shared actual Promise<JuncSocket<FromSocket, ToSocket>> connect<FromSocket, ToSocket>( Context clientContext ) {
		if ( closed ) {
			return clientContext.rejectedPromise( ServiceClosedError() );
		}
		else if ( blocked ) {
			return clientContext.rejectedPromise( ServiceBlockedError() );
		}
		else {
			value [client, service] = junc.socketPair<From|FromSocket, To|ToSocket>( clientContext, context );
			addSocket( service );
			messanger.publisher.publish( service );
			return clientContext.resolvedPromise( client );
		}
	}
	
	
	shared actual void close() {
		if ( atomicClosed.compareAndSet( false, true ) ) {
			junc.monitor.removeCounter( address.string + monitored.delimiter + monitored.numberOfSockets );
			junc.monitor.removeMeter( address.string + monitored.delimiter + monitored.connectionRate );
			sockets.forEachActive( closeSocket );
			sockets.clear();
			messanger.publisher.close();
		}
	}
	
}
