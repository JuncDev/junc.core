import herd.junc.api {
	JuncService,
	Message,
	JuncAddress,
	JuncSocket,
	Registration,
	ServiceClosedError
}
import herd.junc.core.concurrency {
	currentContext
}


"Checks the service actually starts listen and new connection to the service
 may be established and then notifies creator on the event."
by( "Lis" )
class JuncServiceEstablisher<From, To> (
	JuncService<From, To> delegate,
	variable Message<JuncService<From, To>, Null>? replier = null
)
		satisfies JuncService<From, To>
{
	shared actual JuncAddress address => delegate.address;
	
	shared actual Boolean blocked => delegate.blocked;
	assign blocked => delegate.blocked = blocked;
	
	shared actual void close() {
		delegate.close();
		if ( exists rep = replier ) {
			replier = null;
			rep.reject( ServiceClosedError() );
		}
	}
	
	shared actual Boolean closed => delegate.closed;
	
	shared actual Integer numberOfSockets => delegate.numberOfSockets;
	
	shared actual Registration onClose( void close() ) => delegate.onClose( close );
	
	shared actual Registration onConnected( void connected( JuncSocket<To,From> socket ) ) {
		if ( exists rep = replier ) {
			replier = null;
			rep.reply( MessageImpl<Null, JuncService<From, To>>( currentContext, null, null, null ) );
		}
		return delegate.onConnected( connected );
	}
	
	shared actual Registration onError( void error( Throwable err ) ) => delegate.onError( error );
	
}
