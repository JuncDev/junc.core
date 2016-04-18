import herd.junc.api {
	LoadLevel
}
import herd.junc.api.monitor {
	Average,
	monitored,
	Monitor
}
import herd.junc.core.utils {
	ListItem,
	DualList,
	ListBody
}

import java.util.concurrent.atomic {
	AtomicBoolean
}


"Performs execution in a one thread."
by( "Lis" )
class SingleThread (
	"ID of the java thread, this single thread is run on." shared Integer threadID,
	"Converts load factor to grade." LoadGrader grader,
	"Time limit used in load calculations." Integer timeLimit,
	"Factor used in flow averaging." Float meanFactor,
	"Optimization is run every `loopsForOptimization`." Integer loopsForOptimization,
	"Optimizing thread executors." ThreadOptimizer optimizer,
	"Monitoring system." Monitor monitor	
)
		extends ListItem<SingleThread>()
{
	
	"Executors work on this thread."
	shared DualList<Executor> executors = DualList<Executor>();
	
	Average loadAverage = monitor.average (
		monitored.thread + monitored.delimiter + threadID.string + monitored.delimiter + monitored.threadLoadLevel
	);
	Average queueLengthAverage = monitor.average (
		monitored.thread + monitored.delimiter + threadID.string + monitored.delimiter + monitored.threadQueuePerLoop
	);


	"Next time to process timed functions."
	variable Integer? nextTime = null;
	
	".`True` if all executors have been processed at high load grade
	 and `false` if only some part has been choosen to process."
	variable Boolean allProcessed = false;
	
	"The thread load grade."
	variable LoadLevel loadGrade = LoadLevel.lowLoadLevel;
	"The thread load level."
	shared LoadLevel loadLevel => loadGrade;
	
	
	variable Float threadProcessTime = 0.0;
	variable Float threadLoadFactor = 0.0;
	variable Float executorTimeAccumulator = 0.0;
	variable Float meanExecutorsLoadFactor = 0.0;

	"Averaged thread load factor."
	shared Float loadFactor => threadLoadFactor;
	
	"Current load factor."
	shared Float executorsLoadFactor => meanExecutorsLoadFactor;
	
	variable Float optimizationTimeCount = 0.0;
	Float optimizationTimePeriod
			=>	loopsForOptimization * threadProcessTime
				* threadProcessTime * timeLimit / ( 1 + executorTimeAccumulator );
	
	
	"Signal this thread uses."
	SignalWait signal = SignalWait();

	
	"Context is running."
	AtomicBoolean runningAtomic = AtomicBoolean( true );
	shared Boolean running => runningAtomic.get();
	
	"Adds executor to the thread or creates new one if [[added]] is `null`.  
	 Returns added executor."
	shared Executor addExecutor( Executor? added = null ) {
		if ( exists executor = added ) {
			executor.signal.reference = signal;
			executors.addItem( executor );
			return executor;
		}
		else {
			Executor executor = Executor( signal, grader, timeLimit, meanFactor );
			executors.addItem( executor );
			return executor;
		}
	}

	"Signals to start processing."
	shared void signalProcessing() => signal.signal();
	
	
	"Executes all ported functions and stops this thread."
	shared void complete() {
		registration.cancel();
		if ( runningAtomic.compareAndSet( true, false ) ) { signal.signal(); }
	}
	
	
	shared void run() {
		processExecutors();
		threadProcessTime = 0.0;
		
		while ( running ) {
			// calculate wait time
			Integer startWait = system.milliseconds;
			Integer waitTime;
			if ( exists n = nextTime ) {
				waitTime = n - startWait > 0 then n - startWait else -1;
			}
			else {
				waitTime = optimizationTimePeriod.integer > 0 then optimizationTimePeriod.integer else 0;
			}
			
			// wait signal or time
			if ( waitTime > -1 ) { signal.await( waitTime ); }
			optimizationTimeCount += system.milliseconds - startWait;
			
			// process execution cycle
			if ( executors.size > 0 ) {
				processExecutors();
				// optimize - move some executors away
				if ( optimizationTimeCount > optimizationTimePeriod || executors.size == 0 ) {
					optimizationTimeCount = 0.0;
					if ( running ) { optimizer.optimize( this, true ); }
				}
			}
			else if ( running ) {
				// optimize now if empty
				optimizer.optimize( this, false );
			}
		}
		
		registration.cancel();
		monitor.removeAverage (
			monitored.thread + monitored.delimiter + threadID.string + monitored.delimiter + monitored.threadLoadLevel
		);
		monitor.removeAverage (
			monitored.thread + monitored.delimiter + threadID.string + monitored.delimiter + monitored.threadQueuePerLoop
		);
	}
	
	
	"`Executor` if it contains timer or executor load grade is high and `null` otherwise."
	ListBody<Executor>? highLoadGrade( ListBody<Executor> executor )
			=> if ( executor.body.containsTimer || executor.body.loadLevel == LoadLevel.highLoadLevel ) then executor else null;
	
	"`Executor` if it contains timer or executor load grade is high or middle and `null` otherwise."
	ListBody<Executor>? highOrMiddleLoadGrade( ListBody<Executor> executor )
			=> if ( executor.body.containsTimer || executor.body.loadLevel != LoadLevel.lowLoadLevel ) then executor else null;
	
	
	"Processes all executors.  Returns wait time to execute timed functions or 0 if no."
	void processExecutors() {
		Integer startTime = system.nanoseconds;
		nextTime = null;
		executorTimeAccumulator = 0.0;
		meanExecutorsLoadFactor = 0.0;
		
		switch ( loadGrade )
		case ( LoadLevel.lowLoadLevel ) {
			// at low load grade - process all
			executors.forEachActive( processExecutor );
		}
		case ( LoadLevel.middleLoadLevel ) {
			// at middle load grade process all / only middle or high loaded executors in turn
			if ( allProcessed && running ) {
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
			if ( allProcessed && running ) {
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
		Float currentThreadProcessTime = 0.000001 * ( system.nanoseconds - startTime );
		threadProcessTime = meanFactor * currentThreadProcessTime + ( 1 - meanFactor ) * threadProcessTime;
		threadLoadFactor = 1.0 - 1.0 / ( 1.0 + executorTimeAccumulator / threadProcessTime / timeLimit );
		// thread load grade
		loadGrade = grader.grade( loadFactor, loadGrade );
		loadAverage.sample( ( 100 * loadFactor + 0.5 ).integer.float );
			
		optimizationTimeCount += currentThreadProcessTime;
			
		if ( executors.size > 0 ) {
			meanExecutorsLoadFactor /= executors.size;
		}
		
	}
	
	"Process the given executor."
	void processExecutor( ListBody<Executor> executorBody ) {
		// execute
		Executor executor = executorBody.body;
		Integer ret = executor.process();
		if ( executor.running ) {
			queueLengthAverage.sample( ret.float );
			executorTimeAccumulator += executor.meanProcessTime * executor.meanProcessTime;
			meanExecutorsLoadFactor += executor.loadFactor;
			// time to process timed functions
			if ( exists execTimed = executor.timelyExecution ) {
				if ( exists n = nextTime ) {
					if ( execTimed < n ) { nextTime = execTimed; }
				}
				else { nextTime = execTimed; }
			}
		}
		else {
			executorBody.registration.cancel();
		}
	}
	
}
