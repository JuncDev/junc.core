import herd.asynctest {
	TestSuite,
	TestInitContext,
	sequential,
	AsyncTestContext
}
import herd.junc.core {
	Railway,
	startJuncCore,
	JuncOptions
}
import herd.junc.api.monitor {
	LogWriter,
	Priority
}
import ceylon.test {
	test
}
import herd.junc.api {
	ServiceAddress,
	JuncService,
	JuncSocket,
	Message,
	JuncTrack,
	TimeEvent,
	PeriodicTimeRow
}
import herd.asynctest.match {
	EqualTo,
	CloseTo,
	EqualObjects
}


alias IntegerMessage => Message<Integer, Integer>;


abstract class Transaction( shared Integer code )
		of OpenTransaction | SecureTransaction
		extends Object()
{}

class OpenTransaction( Integer code ) extends Transaction( code ) {
	shared actual Boolean equals(Object that) {
		if (is OpenTransaction that) {
			return code==that.code;
		}
		else {
			return false;
		}
	}
	shared actual Integer hash => code;
}

class SecureTransaction( Integer code ) extends Transaction( code ) {
	shared actual Boolean equals(Object that) {
		if (is SecureTransaction that) {
			return code==that.code;
		}
		else {
			return false;
		}
	}
	shared actual Integer hash => code;
}


sequential
shared class BasicJuncCore() satisfies TestSuite {
	
	ServiceAddress addressSocket = ServiceAddress( "socket" );
	ServiceAddress addressMessage = ServiceAddress( "message" );
	ServiceAddress addressType = ServiceAddress( "typed message" );
	
	SimpleStation station = SimpleStation();
	variable Railway? railway = null;
	variable Integer messageToSend = 1;
	
	shared actual void dispose() {
		if ( exists r = railway ) {
			r.stop();
		}
	}
	
	shared actual void initialize( TestInitContext initContext ) {
		startJuncCore(
			JuncOptions {
				monitorPeriod = 0;
			}
		).onComplete (
			(Railway railway) {
				this.railway = railway;
				
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
				
				railway.deployStation( station ).onComplete (
					(Object obj) => initContext.proceed(),
					(Throwable reason) => initContext.abort( reason, "station deploying" )
				);
			}
		);
	}
	
	
	void echoService( AsyncTestContext context )( JuncSocket<Integer, Integer> socket ) {
		socket.onData (
			(Integer data) => socket.publish( data )
		);
		socket.onError( (Throwable err) => context.fail(err, "``addressSocket`` service") );
	}

	void echoClient( AsyncTestContext context )( JuncSocket<Integer, Integer> socket ) {
		variable Integer toSend = 1;
		socket.onData (
			(Integer data) {
				context.assertThat( data, EqualTo( toSend ), "", true );
				if ( ++ toSend < 4 ) {
					socket.publish( toSend );
				}
				else {
					context.complete();
				}
			}
		);
		socket.onError( (Throwable err) => context.fail(err, "``addressSocket`` client") );
		socket.publish( toSend );
	}

	
	"Test on connecting to service and sending data using socket."
	shared test void socket( AsyncTestContext context ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		
		context.start();
		track.registerService<Integer, Integer, ServiceAddress>( addressSocket ).onComplete (
			(JuncService<Integer, Integer> service) {
				service.onConnected( echoService( context ) );
				track.connect<Integer, Integer, ServiceAddress>( addressSocket ).onComplete (
					echoClient( context ),
					(Throwable err) {
						context.fail(err, "``addressSocket`` connection");
						context.complete();
					}
				);
			},
			(Throwable err) {
				context.fail(err, "``addressSocket`` service registration");
				context.complete();
			}
		);
	}
	

	void messageListener(JuncTrack track, AsyncTestContext context)(IntegerMessage data) {
		data.reply (
			track.createMessage (
				data.body,
				messageListener( track, context ),
				(Throwable err) {
					context.fail(err, "``addressMessage`` message delivery to service");
					context.complete();
				}
			)
		);
	}
	
	void messageConsumer(JuncTrack track, AsyncTestContext context)(IntegerMessage data) {
		context.assertThat( data.body, EqualTo( messageToSend ), "", true );
		if ( ++messageToSend < 4 ) {
			data.reply (
				track.createMessage (
					messageToSend,
					messageConsumer( track, context ),
					(Throwable err) {
						context.fail(err, "``addressMessage`` message delivery");
						context.complete();
					}
				)
			);
		}
		else {
			context.complete();
		}
	}
	
	
	void echoMessageServer( AsyncTestContext context )( JuncSocket<IntegerMessage, IntegerMessage> socket ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		socket.onData (
			messageListener( track, context )
		);
		socket.onError( (Throwable err) => context.fail(err, "``addressMessage`` service") );
	}
	
	void echoMessageClient( AsyncTestContext context )( JuncSocket<IntegerMessage, IntegerMessage> socket ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		socket.onError( (Throwable err) => context.fail(err, "``addressMessage`` client") );
		socket.publish (
			track.createMessage (
				messageToSend,
				messageConsumer( track, context ),
				(Throwable err) {
					context.fail(err, "``addressMessage`` message delivery");
					context.complete();
				}
			)
		);
	}
	

	"Test on connecting to service using socket of `Message` type and sending data via message."
	shared test void message( AsyncTestContext context ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		
		context.start();
		track.registerService<IntegerMessage, IntegerMessage, ServiceAddress>( addressMessage ).onComplete (
			(JuncService<IntegerMessage, IntegerMessage> service) {
				service.onConnected( echoMessageServer( context ) );
				track.connect<IntegerMessage, IntegerMessage, ServiceAddress>( addressMessage ).onComplete (
					echoMessageClient( context ),
					(Throwable err) {
						context.fail(err, "``addressMessage`` connection");
						context.complete();
					}
				);
			},
			(Throwable err) {
				context.fail(err, "``addressMessage`` service registration");
				context.complete();
			}
		);
	}
	
	
	"Test on simple interval timer."
	shared test void intervalTimer( AsyncTestContext context ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		
		context.start();
		
		variable Integer fires = 0;
		variable Integer? prevTime = null;
		Integer totalFires = 4;
		Integer delay = 250;
		
		value timer = track.createTimer( PeriodicTimeRow( delay, totalFires ) );
		timer.onData (
			(TimeEvent event) {
				fires ++;
				if ( exists t = prevTime ) {
					context.assertThat( event.time - t, CloseTo( delay, delay / 20 ), "timer delay of ``fires``", true );
				}
				else {
					context.assertThat( fires, EqualTo( 1 ), "first timer fire" );
				}
				prevTime = event.time;
				context.assertThat( fires, EqualTo( event.count ), "timer fire count" );
			}
		);
		timer.onClose (
			() {
				context.assertThat( fires, EqualTo( totalFires ), "total number of timer fire", true );
				context.complete();
			}
		);
		timer.onError( context.fail );
		timer.start();
		
	}
	
	
	void transactionService( AsyncTestContext context )( JuncSocket<Transaction, Transaction> socket ) {
		socket.onData (
			(OpenTransaction data) => socket.publish( data )
		);
		socket.onData (
			(SecureTransaction data) => socket.publish( data )
		);
		socket.onError( (Throwable err) => context.fail(err, "``addressType`` service") );
	}
	
	
	void transactionClient( AsyncTestContext context )( JuncSocket<Transaction, Transaction> socket ) {
		variable Integer toSend = 1;
		OpenTransaction open = OpenTransaction( 1 ); 
		SecureTransaction secure = SecureTransaction( 1 );
		socket.onData (
			(OpenTransaction data) {
				context.assertThat( data, EqualObjects( open ), "", true );
				if ( ++ toSend > 2 ) {
					context.complete();
				}
			}
		);
		socket.onData (
			(SecureTransaction data) {
				context.assertThat( data, EqualObjects( secure ), "", true );
				if ( ++ toSend > 2 ) {
					context.complete();
				}
			}
		);
		socket.onError( (Throwable err) => context.fail( err, "``addressType`` client" ) );
		socket.publish( open );
		socket.publish( secure );
	}
	
	"Test on connecting to service and sending data of different type using socket."
	shared test void typedMessage( AsyncTestContext context ) {
		"Test is not correctly initialized."
		assert( exists track = station.track );
		
		context.start();
		track.registerService<Transaction, Transaction, ServiceAddress>( addressType ).onComplete (
			(JuncService<Transaction, Transaction> service) {
				service.onConnected( transactionService( context ) );
				track.connect<Transaction, Transaction, ServiceAddress>( addressType ).onComplete (
					transactionClient( context ),
					(Throwable err) {
						context.fail(err, "``addressType`` connection");
						context.complete();
					}
				);
			},
			(Throwable err) {
				context.fail(err, "``addressType`` service registration");
				context.complete();
			}
		);
	}
	
}
