import herd.junc.api {
	LoadLevel
}
import herd.junc.api.monitor {
	Average,
	monitored
}
import herd.junc.core.metric {
	emptyAverage
}
import herd.junc.core.utils {
	TwoWayList,
	ListItem
}

import java.lang {
	Runnable,
	Thread
}
import java.util.concurrent.atomic {
	AtomicBoolean
}


"Performs execution in a one thread."
by( "Lis" )
class SingleThread (
	"number of samples to calculate load factor" Integer sampleCapacity,
	"percent the control takes from whole cycle at half load" Float controlPercent,
	"converts load factor to grade" LoadGrader grader,
	"optimizing thread executors" ThreadOptimizer optimizer
)
		extends ListItem<SingleThread>()
		satisfies Runnable
{
	
	"executors work on this thread"
	shared TwoWayList<Executor> executors = TwoWayList<Executor>();
	
	variable Average loadAverage = emptyAverage;
	variable Average queueAverage = emptyAverage;
	

	"next time to process timed functions"
	variable Integer? nextTime = null;
	
	"`true` if all executors have been processed at high load grade and `false` if only some part has been choosen to process"
	variable Boolean allProcessed = false;
	
	"the thread load grade"
	variable LoadLevel loadGrade = LoadLevel.lowLoadLevel;
	"the thread load level"
	shared LoadLevel loadLevel => loadGrade;
	

	variable Integer lastCompletedNanos = 0;
	variable Float usefullTime = 0.0;
	variable Float lastUsefullTime = 0.0;
	variable Integer actuallyProcessed = 0;
	SmoothedFactor standardTime = SmoothedFactor( 2 * sampleCapacity );
	SmoothedFactor sleepTimeRelative = SmoothedFactor( 2 * sampleCapacity );
	SmoothedFactor threadLoad = SmoothedFactor( 2 * sampleCapacity );
	
	"last calculated load factor - used by thread optimizer to found accidental executor"
	shared Float lastLoadFactor => lastUsefullTime;
	
	"used as constant to avoid zero"
	Float timeTolerance = 0.000001;
	
	"mean thread load factor - as mean in time from max executors load factor"
	shared Float loadFactor => threadLoad.mean;
	Float percentFactor => ( 100 * loadFactor + 0.5 ).integer.float;
	
	variable Integer cycleCount = 0;
	
	"signal this thread uses"
	SignalWait signal = SignalWait();
	
	"context is running"
	AtomicBoolean runningAtomic = AtomicBoolean( true );
	shared Boolean running => runningAtomic.get();
	
	"add executor to the thread or creates new one if [[added]] is `null`.  
	 Returns added executor"
	shared Executor addExecutor( Executor? added = null ) {
		if ( exists a = added ) {
			a.registration.cancel();
			a.signal.reference = signal;
			executors.addToList( a );
			signal.signal();
			return a;
		}
		else {
			Executor a = Executor( signal, sampleCapacity );
			executors.addToList( a );
			return a;
		}
	}
	
	"executes all ported functions and stops this thread"
	shared void complete() {
		registration.cancel();
		if ( runningAtomic.compareAndSet( true, false ) ) { signal.signal(); }
	}
	
	
	shared actual void run() {
		Integer threadID = Thread.currentThread().id;
		String prefix = monitored.thread + monitored.delimiter + threadID.string + monitored.delimiter;
		loadAverage = optimizer.monitor.average( prefix + monitored.threadLoadLevel );
		queueAverage = optimizer.monitor.average( prefix + monitored.threadQueuePerLoop );
		
		lastCompletedNanos = system.nanoseconds;
		while ( running ) {
			if ( exists n = nextTime ) {
				Integer wait = n - system.milliseconds;
				if ( wait > 0 ) { signal.await( wait ); }
				processExecutors();
			}
			else {
				signal.await();
				processExecutors();
			}
		}
		processExecutors();
		
		loadAverage = emptyAverage;
		queueAverage = emptyAverage;
		optimizer.monitor.removeAverage( prefix + monitored.threadLoadLevel );
		optimizer.monitor.removeAverage( prefix + monitored.threadQueuePerLoop );
	}
	
	
	"`executor` if it contains timer or executor load grade is high and `null` otherwise"
	Executor? highLoadGrade( Executor executor )
			=> if ( executor.containsTimer || executor.loadLevel == LoadLevel.highLoadLevel ) then executor else null;
	
	"`executor` if it contains timer or executor load grade is high or middle and `null` otherwise"
	Executor? highOrMiddleLoadGrade( Executor executor )
			=> if ( executor.containsTimer || executor.loadLevel != LoadLevel.lowLoadLevel ) then executor else null;
	
	
	"calculates executor load factor"
	void calculateExecutorLoadFactor( Executor executor ) {
		if ( usefullTime > timeTolerance ) { executor.loadFactor = executor.usefullTime.mean / usefullTime * loadFactor; }
		else { executor.loadFactor = 0.0; }
		// set executor grade
		executor.loadLevel = grader.grade( executor.loadFactor, executor.loadLevel );
	}
	
	"Processes all executors.  Returns wait time to execute timed functions or 0 if no"
	void processExecutors() {
		// if awaited some times - it has to be accumulated to load level calculations
		Integer startTime = system.nanoseconds;
		if ( standardTime.mean > timeTolerance ) {
			// wait time is divided by 2 in order to take into account if system is overloaded
			// and this thread waits another one
			sleepTimeRelative.addSample( 1 / ( 1 + 0.0000005 * ( startTime - lastCompletedNanos ) / standardTime.mean ) );
		}
		else {
			sleepTimeRelative.addSample( 0.0 );
		}
		
		// initialize load calculation values before running
		usefullTime = 0.0;
		lastUsefullTime = 0.0;
		actuallyProcessed = 0;
		nextTime = null;
		
		if ( executors.size > 0 ) {
			switch ( loadGrade )
			case ( LoadLevel.lowLoadLevel ) {
				// at low load grade - process all
				executors.forEachActive( processExecutor );
			}
			case ( LoadLevel.middleLoadLevel ) {
				// at middle load grade process all / only middle or high loaded executors in turn
				if ( !optimizer.extensible && allProcessed && running ) {
					allProcessed = false;
					// process only high or middle loaded executors or those have timer
					executors.forEachActiveMap( highOrMiddleLoadGrade, processExecutor );
					// since not all processed - another processing to be forced
					signal.signal();
				}
				else {
					allProcessed = true;
					executors.forEachActive( processExecutor );
				}
			}
			case ( LoadLevel.highLoadLevel ) {
				// at high load grade process all / only high loaded executors in turn
				if ( !optimizer.extensible && allProcessed && running ) {
					allProcessed = false;
					// process only high loaded executors or those have timer
					executors.forEachActiveMap( highLoadGrade, processExecutor );
					// since not all processed - another processing to be forced
					signal.signal();
				}
				else {
					allProcessed = true;
					executors.forEachActive( processExecutor );
				}
			}
			
			// thread load factor
			lastCompletedNanos = system.nanoseconds;
			Float deltaT = 0.000001 * ( lastCompletedNanos - startTime ) - usefullTime;
			if ( deltaT > timeTolerance ) { standardTime.addSample( deltaT ); }
			else { standardTime.addSample( 2 * timeTolerance ); }
			Float mean = standardTime.mean;
			if ( mean > timeTolerance ) {
				threadLoad.addSample( 1 - 1 / ( 1 + controlPercent * sleepTimeRelative.mean * usefullTime / mean ) );
			}
			else { threadLoad.addSample( 0.001 ); }
			
			// thread load grade
			loadGrade = grader.grade( loadFactor, loadGrade );
			loadAverage.sample( percentFactor );
			
			// calculate load factor for each executor
			executors.forEachActive( calculateExecutorLoadFactor );
			
			// optimize - move some executors away
			if ( ++ cycleCount >= sampleCapacity ) {
				cycleCount = 0;
				if ( running ) {
					// used by optimizer to define executor to move out
					try {
						if ( actuallyProcessed > 0 ) {
							lastUsefullTime = lastUsefullTime / actuallyProcessed / usefullTime * loadFactor;
						}
						else { lastUsefullTime = 0.5; }
					}
					catch ( Throwable err ) { lastUsefullTime = 0.5; }
					optimizer.optimize( this );
				}
			}
		}		
		else if ( running ) {
			// optimize now if empty
			lastUsefullTime = 0.0;
			optimizer.optimize( this );
		}
	}
	
	"process current execution stack"
	void processExecutor( Executor executor ) {
		// execute
		try { queueAverage.sample( executor.process().float ); }
		catch ( Throwable err ) {}
		usefullTime += executor.usefullTime.mean;
		lastUsefullTime += executor.lastUsefullTime;
		actuallyProcessed ++;
		// time to process timed functions
		if ( exists execTimed = executor.timelyExecution ) {
			if ( exists n = nextTime ) {
				if ( execTimed < n ) { nextTime = execTimed; }
			}
			else { nextTime = execTimed; }
		}
	}
	
}
