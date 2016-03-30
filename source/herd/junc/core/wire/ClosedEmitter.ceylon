import herd.junc.api {
	Emitter,
	Registration
}
import herd.junc.core.utils {
	emptyRegistration
}


"Emitter which is always closed."
by( "Lis" )
object closedEmitter satisfies Emitter<Object>
{
	
	shared actual Registration onClose( Anything() close ) {
		close();
		return emptyRegistration;
	}
	
	shared actual Registration onData<SubItem>( Anything(SubItem) data )
			given SubItem satisfies Object => emptyRegistration;
	
	shared actual Registration onEmit<SubItem>( Anything(SubItem) data, Anything(Throwable) error, Anything() close )
			given SubItem satisfies Object => emptyRegistration;
	
	shared actual Registration onError( Anything(Throwable) error ) => emptyRegistration;
	
}
