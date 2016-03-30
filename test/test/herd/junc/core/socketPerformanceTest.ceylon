import herd.junc.api {

	JuncTrack,
	Station,
	ServiceAddress,
	JuncSocket,
	JuncService,
	Promise,
	TimeEvent,
	Junc,
	PeriodicTimeRow
}
import herd.junc.api.monitor {

	Counter,
	Average,
	Meter,
	LogWriter,
	Priority
}
import herd.junc.core {

	startJuncCore,
	JuncOptions,
	Railway
}


shared void runSocketPerformanceTest() {
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
			
			railway.deployStation( SocketPerformanceTestStation( 500 ) );
		}
	);
	
}


class SocketPerformanceTestStation( Integer maxSockets ) satisfies Station
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
	
	
	void toService( JuncSocket<Integer, Integer> socket ) {
		if ( exists s = sockets ) { s.increment(); }
		socket.publish( system.milliseconds );
		socket.onData (
			(Integer timeStamp) {
				if ( exists ave = response ) {
					ave.sample( ( system.milliseconds - timeStamp ).float );
				}
				socket.publish( system.milliseconds );
			}
		);
	}

	
	void onService( JuncSocket<Integer, Integer> socket ) {
		socket.onData ( 
			(Integer timeStamp) {
				if ( exists m = messages ) { m.tick(); }
				if ( exists ave = responseServer ) {
					ave.sample( ( system.milliseconds - timeStamp ).float );
				}
				socket.publish( timeStamp );
			}
		);
	}

	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {
		sockets = junc.monitor.counter( scoketsNumber );
		response = junc.monitor.average( responseRate );
		responseServer = junc.monitor.average( serverRate );
		messages = junc.monitor.meter( messageRate );
		
		
		return track.registerService<Integer, Integer, ServiceAddress>( address ).onComplete (
			( JuncService<Integer, Integer> service ) {
				service.onConnected( onService );
				value timer = track.createTimer( PeriodicTimeRow( 250, maxSockets / 10 ) );
				timer.onData (
					(TimeEvent event) {
						for ( i in 0:10 ) {
							track.connect<Integer, Integer, ServiceAddress>( address ).onComplete( toService );
						}
					}
				);
				timer.start();
			},
			( Throwable err ) => print( "service registration error ``err``" )
		);
	}
	
}
