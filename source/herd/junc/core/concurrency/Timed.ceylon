import herd.junc.api {
	Timer,
	Emitter,
	Publisher,
	TimeRow,
	Registration,
	TimeEvent
}
import herd.junc.core.utils {
	ListItem
}


"timer representation"
by( "Lis" )
class Timed (
	"emitting with timer fires" Emitter<TimeEvent> onTime,
	"publishing to [[onTime]]" Publisher<TimeEvent> publisher,
	"strategy to fires" TimeRow times,
	"process timers start / resume" TimedProcessor processor
)
		extends ListItem<Timed>()
{
	
	variable Integer? nextTime = null;
	
	variable Boolean started = false;
	
	variable Integer counts = 0;
	
	shared Boolean completed => publisher.closed;
	
	shared Integer? nextFire => nextTime;


	shared void process( Integer time ) {
		if ( completed ) {
			nextTime = null;
			registration.cancel();
		}
		else if ( started, exists timeToFire = nextTime, timeToFire < time ) {
			publisher.publish( TimeEvent( timer, timeToFire, ++ counts ) );
			nextTime = null;
			while ( exists nt = times.nextTime() ) {
				if ( nt > time ) { nextTime = nt; break; }
				else { publisher.publish( TimeEvent( timer, nt, ++ counts ) ); }
			}
			if ( !nextTime exists ) { timer.stop(); }
		}
	}

	
	shared object timer satisfies Timer {
		
		shared actual void pause() {
			if ( !completed && started ) {
				times.pause();
				nextTime = null;
			}
		}
	
		shared actual void resume() {
			if ( !completed && started && !nextTime exists ) {
				nextTime = times.resume( system.milliseconds );
				if ( exists n = nextTime ) { processor.processFrom( n ); }
				else { stop(); }
			}
		}
	
		shared actual void start() {
			if ( !completed && !started ) {
				started = true;
				nextTime = times.start( system.milliseconds );
				if ( exists n = nextTime ) { processor.processFrom( n ); }
				else { stop(); }
			}
		}
	
		shared actual void stop() {
			nextTime = null;
			registration.cancel();
			publisher.close();
		}
		
		shared actual Registration onClose( Anything() close ) => onTime.onClose( close );
		
		shared actual Registration onData<SubItem>( Anything(SubItem) data )
				given SubItem satisfies TimeEvent => onTime.onData<SubItem>( data );
		
		shared actual Registration onEmit<SubItem>( Anything(SubItem) data, Anything(Throwable) error, Anything() close )
				given SubItem satisfies TimeEvent => onTime.onEmit( data, error, close );
		
		shared actual Registration onError( Anything(Throwable) error ) => onTime.onError( error );
		
	}
	
}
