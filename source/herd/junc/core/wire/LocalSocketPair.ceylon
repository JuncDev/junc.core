import herd.junc.api {

	JuncSocket,
	Registration,
	Context
}


"Socket pair."
class LocalSocketPair<From, To> (
	"First socket context." Context first,
	"Second socket context." Context second,
	"Number of messages stored while not listener added." Integer numberOfStoredMessages
) {
	
	// publish to client
	EmitterPublisher<From> toThis = EmitterPublisher<From>( first, numberOfStoredMessages );
	
	// publish to server
	EmitterPublisher<To> toOther = EmitterPublisher<To>( second, numberOfStoredMessages );
	
	// cycling close
	toThis.emitter.onClose( toOther.publisher.close );
	toOther.emitter.onClose( toThis.publisher.close );
	
	// client socket - emits data published by [[toClient]] and publish data to [[toServer]]
	class ToThisSocket() satisfies JuncSocket<From, To>  {
		
		shared actual Boolean closed => toOther.publisher.closed;
		
		shared actual void close() => toOther.publisher.close();
		
		shared actual void publish<SubItem>( SubItem msg )
				given SubItem satisfies To => toOther.publisher.publish<SubItem>( msg );
		
		shared actual void error( Throwable err ) => toOther.publisher.error( err );
		
		
		shared actual Registration onData<SubItem>( Anything(SubItem) data ) given SubItem satisfies From
				=> toThis.emitter.onData( data );
		
		shared actual Registration onError( Anything(Throwable) error ) => toThis.emitter.onError( error );
		
		shared actual Registration onClose( Anything() close ) => toThis.emitter.onClose( close );
		
		shared actual Registration onEmit<SubItem> (
			Anything(SubItem) data, Anything(Throwable) error, Anything() close
		)  given SubItem satisfies From
				=> toThis.emitter.onEmit( data, error, close );
		
	}
	
	// server socket - emits data published by [[toServer]] and publish data to [[toClient]]
	class ToOtherSocket() satisfies JuncSocket<To, From> {
		
		shared actual Boolean closed => toThis.publisher.closed;
		
		shared actual void close() => toThis.publisher.close();
		
		shared actual void publish<SubItem>( SubItem msg )
				given SubItem satisfies From => toThis.publisher.publish<SubItem>( msg );
		
		shared actual void error( Throwable err ) => toThis.publisher.error( err );
		
		
		shared actual Registration onData<SubItem>( Anything(SubItem) data ) given SubItem satisfies To
				=> toOther.emitter.onData( data );
		
		shared actual Registration onError( Anything(Throwable) error ) => toOther.emitter.onError( error );
		
		shared actual Registration onClose( Anything() close ) => toOther.emitter.onClose( close );
		
		shared actual Registration onEmit<SubItem> (
			Anything(SubItem) data, Anything(Throwable) error, Anything() close
		)  given SubItem satisfies To
				=> toOther.emitter.onEmit( data, error, close );
		
	}
	
	
	shared [JuncSocket<From, To>, JuncSocket<To, From>] pair = [ToThisSocket(), ToOtherSocket()];
	
}