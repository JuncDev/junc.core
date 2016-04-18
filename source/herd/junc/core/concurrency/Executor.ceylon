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
	TwoWayList
}

import java.util.concurrent.atomic {
	AtomicBoolean
}
import java.util.concurrent.locks {

	ReentrantLock
}


"Executor - processor which stores all ported functions and executes them when [[process]] called.  
 When new executable added signals to [[signal]].  
 When closed signals immediately to execute all ported function and then errors to all newly ported functions.
 "
by( "Lis" )
class Executor (
	"Used to signal when some executables added." Signal initial,
	"Converts load factor to grade." LoadGrader grader,
	"Time limit used in load calculations." Integer timeLimit,
	"Factor used in flow averaging." Float meanFactor
)
		satisfies CoreProcessor & TimedProcessor
{
	
	"Averaging factor has to be > 0.0 and < 1.0."
	assert ( meanFactor > 0.0 && meanFactor < 1.0 );
	
	TwoWayList<Timed> timedExecutors = TwoWayList<Timed>();	
	variable Integer? nextTime = null;
	"`True` if executor contains at least one timer."
	shared Boolean containsTimer => !timedExecutors.empty;
	
	"List of executables to be executed."
	ReentrantLock executablesLock = ReentrantLock();
	variable Executable? executablesHead = null;
	variable Executable? executablesTail = null;
	
	
	AtomicBoolean isRunning = AtomicBoolean( true );
	
	shared actual Boolean running => isRunning.get();
	
	
	"Signal used to signal that some functions to be executed.  
	 The signal can be modified in order to move processor to another thread."
	shared SignalReference signal = SignalReference( initial );
	
	"Current load level."
	variable LoadLevel currentLoadLevel = LoadLevel.lowLoadLevel;
	
	"Load grade - low, middle or high."
	shared actual LoadLevel loadLevel => currentLoadLevel;
	
	// load level calculation parameters
	variable Float processTime = 0.0;
	
	
	"Averaged process time."
	shared Float meanProcessTime => processTime;
	
	"Load factor from 0. to 1.0."
	shared Float loadFactor => 1.0 - 1.0 / ( 1.0 + processTime / timeLimit );
	
		
	"Puts executable to proceed list."
	see( `function process` )
	void putExecutable( Executable executable ) {
		if ( running ) {
			executablesLock.lock();
			try {
				if ( exists tail = executablesTail ) {
					tail.next = executable;
					executablesTail = executable;
				}
				else {
					executablesTail = executable;
					executablesHead = executable;
				}
				signal.signal();
			}
			finally {
				executablesLock.unlock();
			}
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
		if ( isRunning.compareAndSet( true, false ) ) {
			value res = currentContext.newResolver<Processor>();
			putExecutable( VoidExecutable( () => res.resolve( this ) ) );
			return res.promise;
		}
		else {
			return currentContext.rejectedPromise( ContextStoppedError() );
		}
	}
	
	
	"Runs timed functions.  Returns usefull workload in time. miliseconds.  
	 Return number of actuaaly processed functions."
	Integer processTimed() {
		variable Integer ret = 0;
		if ( exists gt = nextTime, gt < system.milliseconds ) {
			variable Integer? minNext = null;
			timedExecutors.lock();
			variable Timed? ex = timedExecutors.head;
			while ( exists te = ex ) {
				ex = te.next;
				ret ++;
				te.process( system.milliseconds );
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
		return ret;
	}
	
	
	"Actually processed all executables in current list.  
	 Returns number of actually proceeded functions."
	Integer proceedExecutables() {
		variable Integer ret = 0;
		variable Executable? executable;
		executablesLock.lock();
		executable = executablesHead;
		executablesTail = null;
		executablesHead = null;
		executablesLock.unlock();
		// executables are put in reversed order, so iterate the list to put them in correct ordder firstly
		// process executables in correct order
		while ( exists exec = executable ) {
			executable = exec.next;
			exec.proceed();
			ret ++;
		}
		return ret;
	}
	
	
	"Runs all added executables.  Returns number of actually processed functions."
	shared Integer process() {
		// process on context
		Integer startNanos = system.nanoseconds;
		variable Integer processed = 0;
		if ( running ) {
			// process execution queue
			processed = proceedExecutables();
			// process timed functions
			processed += processTimed();
		}
		
		if ( running ) {
			// Calculate load terms
			Float executionTime = 0.000001 * ( system.nanoseconds - startNanos );
			processTime = meanFactor * executionTime + ( 1 - meanFactor ) * processTime;
			currentLoadLevel = grader.grade( loadFactor, currentLoadLevel );
		}
		else {
			// if goes to close after processing - process all posted in previous execute cycle
			proceedExecutables();
		}
		
		return processed;
	}
	
	"Returns time to execute timed functions or `null` if no."
	shared Integer? timelyExecution => nextTime;
	
}
