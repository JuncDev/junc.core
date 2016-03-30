import herd.junc.api {
	Timer,
	Registration,
	TimeEvent
}
import herd.junc.core.utils {
	emptyRegistration
}


"Timer which is always completed."
by( "Lis" )
shared object completedTimer satisfies Timer
{
	
	shared actual void pause() {}
	
	shared actual void resume() {}
	
	shared actual void start() {}
	
	shared actual void stop() {}
	
	shared actual Registration onClose(Anything() close) {
		close();
		return emptyRegistration;
	}
	
	shared actual Registration onData<SubItem>(Anything(SubItem) data)
			given SubItem satisfies TimeEvent => emptyRegistration;
	
	shared actual Registration onEmit<SubItem>(Anything(SubItem) data, Anything(Throwable) error, Anything() close)
			given SubItem satisfies TimeEvent => emptyRegistration;
	
	shared actual Registration onError(Anything(Throwable) error) => emptyRegistration;
	
}
