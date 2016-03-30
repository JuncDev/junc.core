import herd.junc.api {
	JuncTrack,
	JuncSocket,
	Promise,
	Context,
	JuncService,
	LoadLevel,
	JuncAddress,
	ContextStoppedError,
	Timer,
	TimeRow,
	Connector,
	Registration,
	Workshop,
	Emitter,
	JuncEvent,
	Message
}
import herd.junc.core.concurrency {
	currentContext
}


"Track which is always closed - rejects all operations."
by( "Lis" )
object closedTrack satisfies JuncTrack
{
	shared actual Context context => currentContext;
	
	shared actual Boolean closed => true;
	
	shared actual LoadLevel loadLevel => LoadLevel.lowLoadLevel;
	
	shared actual void close() {}
	
	shared actual Promise<JuncSocket<To, From>> connect<To, From, Address> (
		Address address
	) given Address satisfies JuncAddress => currentContext.rejectedPromise( ContextStoppedError() );
	
	shared actual Promise<JuncService<From, To>> registerService<From, To, Address> (
		Address address
	) given Address satisfies JuncAddress => currentContext.rejectedPromise( ContextStoppedError() );
	
	shared actual Timer createTimer( TimeRow timeRow ) => completedTimer;
	
	shared actual Message<Body, Reply> createMessage<Body, Reply> (
		Body body, Anything(Message<Reply, Body>)? replyHandler, Anything(Throwable)? rejectHandler
	) {
		if ( exists rejectHandler ) {
			rejectHandler( ContextStoppedError() );
		}
		return RejectedMessage<Body, Reply>( body, ContextStoppedError() );
	}
	
	shared actual Promise<Result> executeBlocked<Result>( Result() run )
			=> currentContext.rejectedPromise( ContextStoppedError() );
	
	shared actual Promise<Registration> registerConnector<From, To, Address> (
		Connector<From, To, Address> connector
	) given Address satisfies JuncAddress => currentContext.rejectedPromise( ContextStoppedError() );
	
	shared actual Promise<Registration> registerWorkshop<From, To, Address> (
		Workshop<From, To, Address> provider
	) given Address satisfies JuncAddress => currentContext.rejectedPromise( ContextStoppedError() );
	
	shared actual Emitter<JuncEvent> juncEvents => closedEmitter;
	
}
