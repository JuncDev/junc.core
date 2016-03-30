import herd.junc.api.monitor {

	LogWriter,
	Priority,
	Counter,
	Average,
	Meter
}
import herd.junc.api {

	Station,
	JuncTrack,
	Junc,
	Promise,
	JuncService,
	ServiceAddress,
	JuncSocket,
	PeriodicTimeRow,
	TimeEvent,
	Message
}
import herd.junc.core {

	startJuncCore,
	JuncOptions,
	Railway
}


shared void runMessagePerformanceTest() {
	print( "start testing" );
	
	startJuncCore(
		JuncOptions {
			monitorPeriod = 5;
		}
	).onComplete (
		( Railway railway ) {
			railway.addLogWriter (
				object satisfies LogWriter {
					shared actual void writeLogMessage (
						String identifier,
						Priority priority,
						String message,
						Throwable? throwable
					) {
						String str = if ( exists t = throwable ) then " with error ``t.message```" else "";
						print( "``priority``: ``identifier`` sends '``message``'``str``" );
					}
				}
			);
			railway.addMetricWriter( PerformanceMetricWriter() );
			
			railway.deployStation( MessagePerformanceTestStation( 500 ) );
		}
	);
	
}


alias RateMessage => Message<Integer, Integer>;

class MessagePerformanceTestStation( Integer maxSockets ) satisfies Station
{

	String scoketsNumber = "socketsNumber";
	String responseRate = "responseRate";
	String serverRate = "serverRate";
	String messageRate = "messageRate";
	
	variable Counter? sockets = null;
	variable Average? response = null;
	variable Average? responseServer = null;
	variable Meter? messages = null;

	ServiceAddress address = ServiceAddress( "test" );
	
	
	void printError( Throwable err ) => print( err );
	
	
	void toServiceRate( JuncTrack track )( RateMessage timeStamp ) {
		if ( exists ave = response ) {
			ave.sample( ( system.milliseconds - timeStamp.body ).float );
		}
		timeStamp.reply( track.createMessage( system.milliseconds, toServiceRate( track ), printError ) );
	}
	
	void toService( JuncTrack track )( JuncSocket<RateMessage, RateMessage> socket ) {
		if ( exists s = sockets ) { s.increment(); }
		socket.publish( track.createMessage( system.milliseconds, toServiceRate( track ), printError ) );
	}

	void onServiceRate( JuncTrack track )( RateMessage timeStamp ) {
		if ( exists m = messages ) { m.tick(); }
		if ( exists ave = responseServer ) {
			ave.sample( ( system.milliseconds - timeStamp.body ).float );
		}
		timeStamp.reply( track.createMessage( timeStamp.body, onServiceRate( track ), printError ) );
	}

	void onService( JuncTrack track )( JuncSocket<RateMessage, RateMessage> socket ) {
		socket.onData( onServiceRate( track ) );
	}
	
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {
		sockets = junc.monitor.counter( scoketsNumber );
		response = junc.monitor.average( responseRate );
		responseServer = junc.monitor.average( serverRate );
		messages = junc.monitor.meter( messageRate );
		
		return track.registerService<RateMessage, RateMessage, ServiceAddress>( address ).onComplete (
			( JuncService<RateMessage, RateMessage> service ) {
				service.onConnected( onService( track ) );
				value timer = track.createTimer( PeriodicTimeRow( 250, maxSockets / 10 ) );
				timer.onData (
					(TimeEvent event) {
						for ( i in 0:10 ) {
							track.connect<RateMessage, RateMessage, ServiceAddress>( address ).onComplete( toService( track ) );
						}
					}
				);
				timer.start();
			},
			( Throwable err ) => print( "service registration error ``err``" )
		);
	}
	
}
