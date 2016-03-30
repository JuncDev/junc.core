import herd.junc.api {
	ContextStoppedError,
	Promise,
	Deferred,
	LoadLevel,
	Timer,
	Emitter,
	TimeRow,
	Publisher,
	TimeEvent
}
import herd.junc.core.utils {
	ListItem,
	TwoWayList
}

import java.util.concurrent.atomic {
	AtomicReference
}


"Executor - processor which stores all ported functions and executes them when [[process]] called.  
 When new executable added signals to [[signal]].  
 When closed signals immediately to execute all ported function and then errors to all newly ported functions 
 "
by( "Lis" )
class Executor (
	"used to signal when some executables added" Signal initial,
	"capacity of sampling tocalculate smoothed factor" Integer sampleCapacity
)
		extends ListItem<Executor>()
		satisfies CoreProcessor & TimedProcessor
{
		
	TwoWayList<Timed> timedExecutors = TwoWayList<Timed>();	
	variable Integer? nextTime = null;
	"`true` if executor contains at least one timer"
	shared Boolean containsTimer => !timedExecutors.empty;
	
	"list of executables to be executed"
	AtomicReference<Executable> executables = AtomicReference<Executable>();
	
	
	shared actual variable Boolean running = true; 
	
	
	"signal used to signal that some functions to be executed.    
	 The signal can be modified in order to move processor to another thread"
	shared SignalReference signal = SignalReference( initial );
	
	"current load level"
	AtomicReference<LoadLevel> atomicLoadGrade = AtomicReference<LoadLevel>( LoadLevel.lowLoadLevel );
	
	"load grade - low, middle or high"
	shared actual LoadLevel loadLevel => atomicLoadGrade.get();
	assign loadLevel => atomicLoadGrade.set( loadLevel );
	
	
	"usefull workload in time, milliseconds"
	shared SmoothedFactor usefullTime = SmoothedFactor( sampleCapacity );
	variable Float lastExecutionTime = 0.0;
	shared Float lastUsefullTime => lastExecutionTime;
	"executor load factor - calculated by thread"
	shared variable Float loadFactor = 0.0;
	
		
	"put executable to proceed list"
	see( `function process` )
	void putExecutable( Executable executable ) {
		if ( running ) {
			executable.next = executables.getAndSet( executable );
			signal.signal();
		}
		else { executable.reject( ContextStoppedError() ); }
	}
	
	
	shared actual void execute( void run(), Anything(Throwable)? notifyError )
			=> putExecutable( VoidExecutable( run, notifyError ) );
	
	shared actual void executeWithArgument<Argument> (
		Anything(Argument) run,
		Argument arg,
		Anything(Throwable)? notifyError
	) => putExecutable( ArgumentedExecutable( run, arg, notifyError ) );
	
	shared actual Promise<Result> executeWithResults<Result, Argument> (
		Result(Argument) run,
		Argument arg
	) {
		Deferred<Result> def = newResolver<Result>();		
		putExecutable( ResultExecutable( run, arg, def ) );
		return def.promise;
	}
	
	shared actual Promise<Result> executeWithPromise<Result, Argument> (
		Promise<Result>(Argument) run,
		Argument arg
	) {
		Deferred<Result> def = newResolver<Result>();		
		putExecutable( PromiseExecutable( run, arg, def ) );
		return def.promise;
	}

	shared actual void processFrom( Integer time ) {
		if ( exists n = nextTime ) {
			if ( time < n ) { nextTime = time; }
		}
		else { nextTime = time; }
		signal.signal();
	}
	
	shared actual Timer createTimer( Emitter<TimeEvent> onTime, Publisher<TimeEvent> publisher, TimeRow times ) {
		Timed timer = Timed( onTime, publisher, times, this );
		timedExecutors.addToList( timer );
		return timer.timer;
	}
	
	
	shared actual Promise<Processor> close() {
		if ( running ) {
			running = false;
			value res = currentContext.newResolver<Processor>();
			putExecutable( VoidExecutable( () => res.resolve( this ) ) );
			return res.promise;
		}
		else {
			return currentContext.rejectedPromise( ContextStoppedError() );
		}
	}
	
	//shared actual Boolean running => state == stateRunning;
	
	
	"Runs timed functions.  Returns usefull workload in time. miliseconds"
	void processTimed() {
		Integer currentTime = system.milliseconds; 
		if ( exists gt = nextTime, gt < currentTime ) {
			variable Integer? minNext = null;
			timedExecutors.lock();
			variable Timed? ex = timedExecutors.head;
			while ( exists te = ex ) {
				ex = te.next;
				te.process( currentTime );
				if ( exists nt = te.nextFire ) {
					if ( exists min = minNext ) {
						if ( nt < min ) { minNext = nt; }
					}
					else { minNext = nt; }
				}
			}
			timedExecutors.unlock();
			if ( timedExecutors.empty ) { nextTime = null; }
			else { nextTime = minNext; }
		}
	}
	
	
	"Actually processed all executables in current list."
	Integer proceedExecutables() {
		variable Integer processed = 0;
		variable Executable? executable = executables.getAndSet( null );
		// executables are put in reversed order, so iterate the list to put them in correct ordder firstly
		variable Executable? head = executable;
		while ( exists exec = executable ) {
			if ( exists next = exec.next ) {
				next.prev = exec;
			}
			else {
				head = exec;
			}
			executable = exec.next;
		}
		// process executables in correct order
		while ( exists exec = head ) {
			head = exec.prev;
			exec.proceed();
			processed ++;
		}
		return processed;
	}
	
	"Runs all added executables.  Returns number of actually processed functions"
	shared Integer process() {
		// process on context
		variable Integer processed = 0;
		if ( running ) {
			variable Integer executionTime = 0;
			Integer startNanos = system.nanoseconds;
			processed = proceedExecutables();
			executionTime = system.nanoseconds - startNanos;
		
			// process timed functions
			Integer timedStart = system.nanoseconds;
			processTimed();
			executionTime += system.nanoseconds - timedStart;
			lastExecutionTime = 0.000001 * executionTime;
		
			// calculate execution rates
			usefullTime.addSample( lastExecutionTime );
		}
		
		// if goes to close after processing - process all posted in previous execute cycle
		if ( !running ) {
			registration.cancel();
			proceedExecutables();
		}
		
		return processed;
	}
	
	"returns time to execute timed functions or `null` if no"
	shared Integer? timelyExecution => nextTime;
	
}
