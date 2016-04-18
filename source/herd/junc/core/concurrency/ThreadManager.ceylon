import herd.junc.api {
	LoadLevel
}
import herd.junc.api.monitor {
	Monitor,
	Counter,
	monitored
}
import herd.junc.core.utils {
	TwoWayList,
	DualList,
	ListBody
}

import java.lang {
	Runtime
}
import java.util.concurrent.locks {
	ReentrantLock
}


"Manages threads and executors."
by( "Lis" )
class ThreadManager (
	"Factor on available core processor to estimate maximum possible threads.  
	 So maximum number of threads is `coreFactor` * `Runtime.runtime.availableProcessors()`."
	Float coreFactor,
	"Converts load factor to grade."
	LoadGrader grader,
	"Optimization is run every `loopsForOptimization`."
	Integer loopsForOptimization,
	"Time limit used in load calculations."
	Integer timeLimit,
	"Factor used in flow averaging."
	Float meanFactor,
	"Monitor to store context metrics."
	Monitor monitor
)
	satisfies ThreadOptimizer
{
	
	Float actualCoreFactor = if ( coreFactor > 0.0 ) then coreFactor else 0.0;
	
	Counter numberOfThreads = monitor.counter( monitored.numberOfThreads );
	
	TwoWayList<SingleThread> threads = TwoWayList<SingleThread>();
	
	ReentrantLock optimizationLock = ReentrantLock();
	
	variable ThreadLauncher? launcher = null;

	
	"Removes and closes thread."
	void removeThread( SingleThread thread ) {
		if ( thread.running ) {
			thread.complete();
			numberOfThreads.decrement();
			monitor.logInfo( monitored.core, "thread has been stopped, total thread number is ``threads.size``" );
		}
	}
	
	"`True` if more threads can be added and `false` otherwise."
	shared Boolean extensible {
		try {
			Integer n = ( actualCoreFactor * Runtime.runtime.availableProcessors() + 0.5 ).integer;
			if ( n <= 0 ) { return threads.size == 0; }
			else { return threads.size < n; }
		}
		catch ( Throwable err ) { return false; }
	}
	
	"New thread started callback."
	void newThreadStarted( SingleThread thread ) {
		optimizationLock.lock();
		try {
			launcher = null;
			threads.addToList( thread );
			numberOfThreads.increment();
			monitor.logInfo( monitored.core, "new thread has been started, total thread number is ``threads.size``" );
		}
		finally {
			optimizationLock.unlock();
		}
	}
	
	"Creates new thread if possible."
	void createThread (
		"Callback which has to be called from newly created thread when started."
		void action( SingleThread thread ),
		"Callback which has to be called if impossible to create new thread - lime has been reached."
		void noThreadAction()
	) {
		optimizationLock.lock();
		try {
			if ( exists threadLauncher = launcher ) {
				threadLauncher.addCallback( action );
			}
			else if ( extensible ) {
				ThreadLauncher threadLauncher = ThreadLauncher (
					grader, timeLimit, meanFactor, loopsForOptimization, this, monitor
				);
				launcher = threadLauncher;
				threadLauncher.addCallback( newThreadStarted );
				threadLauncher.addCallback( action );
				threadLauncher.start();
			}
			else {
				monitor.logDebug( monitored.core, "unable to create new thread - limit on thread number has been reached" );
				noThreadAction();
			}
		}
		finally {
			optimizationLock.unlock();
		}
	}
	
	"Returns thread with lowest grade."
	SingleThread? findLowestGradeThreadExcept( "Thread to except from search." SingleThread except ) {
		threads.lock();
		try {
			variable Float minLoad = 1.0;
			variable SingleThread? ret = null;
			variable SingleThread? next = threads.head;
			while ( exists thread = threads.nextActive( next ) ) {
				next = thread.next;
				if ( thread.running && thread.threadID != except.threadID ) {
					if ( thread.executors.empty ) { return thread; }
					else if ( thread.loadFactor < minLoad ) {
						minLoad = thread.loadFactor;
						ret = thread;
					}
				}
			}
			return ret;
		}
		finally { threads.unlock(); }
	}
	
	"Returns thread with lowest grade."
	SingleThread? findLowestGradeThread() {
		threads.lock();
		try {
			variable Float minLoad = 1.0;
			variable SingleThread? ret = null;
			variable SingleThread? next = threads.head;
			while ( exists thread = threads.nextActive( next ) ) {
				next = thread.next;
				if ( thread.running ) {
					if ( thread.executors.empty ) { return thread; }
					else if ( thread.loadFactor < minLoad ) {
						minLoad = thread.loadFactor;
						ret = thread;
					}
				}
			}
			return ret;
		}
		finally { threads.unlock(); }
	}

	
	"Returns executor with lowest grade from specified `executors` list.  
	 Executors don't need blocking or have tri state like threads,
	 since this function called from thread executors belongs to."
	ListBody<Executor>? lowestGradeExecutor( DualList<Executor> executors ) {
		executors.lock();
		try {
			variable Float minLoad = 1.0;
			variable ListBody<Executor>? ret = null;
			variable ListBody<Executor>? next = executors.head;
			while ( exists executor = executors.nextActive( next ) ) {
				next = executor.next;
				if ( executor.body.loadFactor < minLoad ) {
					minLoad = executor.body.loadFactor;
					ret = executor;
				}
			}
			return ret;
		}
		finally { executors.unlock(); }
	}
	
	"Returns executor with the most near load factor to `factorToCompareTo`."
	ListBody<Executor>? nearFactorExecutor( DualList<Executor> executors, Float factorToCompareTo ) {
		executors.lock();
		try {
			variable Float meanFactor = 1.0;
			variable Float minDifference = -1.0;
			variable ListBody<Executor>? ret = null;
			variable ListBody<Executor>? next = executors.head;
			while ( exists executor = executors.nextActive( next ) ) {
				next = executor.next;
				meanFactor = executor.body.loadFactor - factorToCompareTo;
				if ( meanFactor < 0.0 ) { meanFactor = -meanFactor; }
				if ( minDifference < 0.0 ) {
					minDifference = meanFactor;
					ret = executor;
				}
				else if ( meanFactor < minDifference ) {
					minDifference = meanFactor;
					ret = executor;
				}
			}
			return ret;
		}
		finally { executors.unlock(); }
	}
	
	
	"Adds new executor to specified thread and notifies about."
	void addNewExecutorToThread( void onCreated( Processor processor ) )( SingleThread thread ) {
		Executor executor = thread.addExecutor();
		executor.executeWithArgument( onCreated, executor );
	}
	
	"Creates new executor and notifies when created."
	shared void createExecutor (
		"Callback which has to be called when new executor is created."
		void onCreated( Processor processor )
	) {
		if ( threads.empty ) {
			createThread (
				addNewExecutorToThread( onCreated ),
				() { throw AssertionError( "Unable to create first thread." ); }
			);
		}
		else {
			"At least one thread has to be existed."
			assert ( exists lowestGradeThread = findLowestGradeThread() );
			if ( lowestGradeThread.loadLevel != LoadLevel.highLoadLevel ) {
				Executor executor = lowestGradeThread.addExecutor();
				executor.executeWithArgument( onCreated, executor );
			}
			else {
				createThread (
					addNewExecutorToThread( onCreated ),
					() {
						optimizationLock.lock();
						try {
							"At least one thread has to be existed."
							assert ( exists threadToAdd = findLowestGradeThread() );
							Executor executor = threadToAdd.addExecutor();
							executor.executeWithArgument( onCreated, executor );
						}
						finally {
							optimizationLock.unlock();
						}
					}
				);
			}
		}
	}
	
	
	"Closes all threads and executors."
	shared void close() {
		monitor.removeCounter( monitored.numberOfThreads );
		threads.lock();
		optimizationLock.lock();
		try {
			variable SingleThread? next = threads.head;
			while ( exists thread = threads.nextActive( next ) ) {
				next = thread.next;
				thread.complete();
			}
			numberOfThreads.reset();
		}
		finally {
			threads.unlock();
			optimizationLock.unlock();
		}
	}
	
	
	"Moves one executor from thread `from` to thread `to`."
	void moveExecutor( SingleThread from, SingleThread to ) {
		DualList<Executor> executors = from.executors;
		Integer size = executors.size;
		// extract executor from thread and assign it to threadToMoveTo
		if ( size == 2 ) {
			// try to move executor with lowest load factor to another thread
			if ( exists lowest = lowestGradeExecutor( executors ) ) {
				lowest.registration.cancel();
				to.addExecutor( lowest.body );
				to.signalProcessing();
				from.signalProcessing();
			}
		}
		else if ( size > 2 ) {
			// try to move accidental executor to another thread
			// accidental executor is selected as executor with the most near load level to
			// `thread.lastLoadFactor` - which is mainly accidental
			if ( exists accidental = nearFactorExecutor( executors, from.executorsLoadFactor ) ) {
				accidental.registration.cancel();
				to.addExecutor( accidental.body );
				to.signalProcessing();
				from.signalProcessing();
			}
		}
	}
	
	
	shared actual void optimize( SingleThread thread, Boolean skipWaiting ) {
		if ( !launcher exists && ( !optimizationLock.locked || !skipWaiting ) ) {
			optimizationLock.lock();
			try {
				if ( thread.executors.size == 0 ) {
					// remove thread, since it is empty
					removeThread( thread );
				}
				else {
					value level = thread.loadLevel;
					if ( level == LoadLevel.lowLoadLevel ) {
						// try to move executors to thread with low or middle grades in order to decrease thread numbers
						if ( exists lowest = findLowestGradeThreadExcept( thread ) ) {
							if ( lowest.loadLevel == LoadLevel.lowLoadLevel ) {
								DualList<Executor> executors = thread.executors;
								executors.lock();
								variable ListBody<Executor>? next = executors.head;
								while ( exists executor = executors.nextActive( next ) ) {
									next = executor.next;
									lowest.addExecutor( executor.body );
								}
								executors.unlock();
								executors.clear();
								removeThread( thread );
								lowest.signalProcessing();
						 	}
						}
					}
					else if ( level == LoadLevel.highLoadLevel ) {
						// try to unload thread
						if ( thread.executors.size > 1 ) {
							// thread to assign executor to
							if ( exists lowest = findLowestGradeThreadExcept( thread ) ) {
								if ( lowest.loadLevel != LoadLevel.highLoadLevel ) {
									moveExecutor( thread, lowest );
								}
								else {
									createThread( noop, noop );
									//createThread( (SingleThread th) => moveExecutor( thread, th ), noop );
								}
							}
							else {
								createThread( noop, noop );
								//createThread( (SingleThread th) => moveExecutor( thread, th ), noop );
							}
						}
					}
				}
			}
			catch ( Throwable err ) {
				monitor.logError( monitored.core, "uncaught error in thread ``thread.threadID``", err );
			}
			finally {
				optimizationLock.unlock();
			}
		}
	}
	
}

