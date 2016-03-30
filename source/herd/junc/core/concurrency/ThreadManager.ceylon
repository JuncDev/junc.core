import herd.junc.api {
	LoadLevel
}
import herd.junc.api.monitor {
	Monitor,
	Counter,
	monitored
}
import herd.junc.core.utils {
	TwoWayList
}

import java.lang {
	Runtime,
	Thread
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
	"Persents the controls may take from full execution time at middle load level."
	Float controlPersent,
	"Converts load factor to grade."
	LoadGrader grader,
	"Number of samples to calculate mean value."
	Integer sampleCapacity,
	"Monitor to store context metrics."
	shared actual Monitor monitor
)
	satisfies ThreadOptimizer
{
	
	Float actualCoreFactor = if ( coreFactor > 0.0 ) then coreFactor else 0.0;
	
	Counter numberOfThreads = monitor.counter( monitored.numberOfThreads );
	
	TwoWayList<SingleThread> threads = TwoWayList<SingleThread>();
	
	ReentrantLock optimizationLock = ReentrantLock();

	
	"remove and close thread"
	void removeThread( SingleThread thread ) {
		if ( thread.running ) {
			thread.complete();
			numberOfThreads.decrement();
			monitor.logInfo( monitored.core, "thread has been stopped, total thread number is ``threads.size``" );
		}
	}
	
	"`true` if more threads can be added and `false` otherwise"
	shared actual Boolean extensible {
		try {
			Integer n = ( actualCoreFactor * Runtime.runtime.availableProcessors() + 0.5 ).integer;
			if ( n <= 0 ) { return threads.size == 0; }
			else { return threads.size < n; }
		}
		catch ( Throwable err ) { return false; }
	}
	
	"`true` if all running threads have high load level and no any thread can be added and `false` otherwise"
	shared Boolean overloaded {
		threads.lock();
		try {
			variable Boolean highLoad = true;
			variable SingleThread? th = threads.head;
			while ( exists t = th ) {
				th = t.next;
				if ( t.loadLevel != LoadLevel.highLoadLevel ) {
					highLoad = false;
					break;
				}
			}
			if ( highLoad ) { return !extensible; }
			else { return false; }
		}
		finally { threads.unlock(); }
	}
	
	
	"creates new thread if possible"
	SingleThread? createThread() {
		if ( extensible ) {
			SingleThread st = SingleThread( sampleCapacity, controlPersent, grader, this );
			threads.addToList( st );
			Thread th = Thread( st );
			th.start();
			numberOfThreads.increment();
			monitor.logInfo( monitored.core, "new thread has been started, total thread number is ``threads.size``" );
			return st;
		}
		else {
			monitor.logWarn( monitored.core, "unable to create new thread - limit on thread number has been reached" );
			return null;
		}
	}
	
	"returns thread with lowest grade"
	SingleThread? findLowestGradeThreadExcept( "thread to except from search" SingleThread except ) {
		threads.lock();
		try {
			variable Float minLoad = 1.0;
			variable SingleThread? ret = null;
			variable SingleThread? next = threads.head;
			while ( exists n = threads.nextActive( next ) ) {
				next = n.next;
				if ( n != except ) {
					if ( n.executors.empty ) { return n; }
					else if ( n.loadFactor < minLoad ) {
						minLoad = n.loadFactor;
						ret = n;
					}
				}
			}
			return ret;
		}
		finally { threads.unlock(); }
	}
	
	"returns thread with lowest grade"
	SingleThread? findLowestGradeThread() {
		threads.lock();
		try {
			variable Float minLoad = 1.0;
			variable SingleThread? ret = null;
			variable SingleThread? next = threads.head;
			while ( exists n = threads.nextActive( next ) ) {
				next = n.next;
				if ( n.executors.empty ) { return n; }
				else if ( n.loadFactor < minLoad ) {
					minLoad = n.loadFactor;
					ret = n;
				}
			}
			return ret;
		}
		finally { threads.unlock(); }
	}

	
	"Returns executor with lowest grade.  
	 Executors don't need blocking or have tri state like threads,
	 since this function called from thread executors belongs to"
	Executor? lowestGradeExecutor( TwoWayList<Executor> executors ) {
		executors.lock();
		try {
			variable Float minLoad = 1.0;
			variable Executor? ret = null;
			variable Executor? next = executors.head;
			while ( exists n = executors.nextActive( next ) ) {
				next = n.next;
				if ( n.loadFactor < minLoad ) {
					minLoad = n.loadFactor;
					ret = n;
				}
			}
			return ret;
		}
		finally { executors.unlock(); }
	}
	
	"returns executor with the most near load factor to `factorToCompareTo`"
	Executor? nearFactorExecutor( TwoWayList<Executor> executors, Float factorToCompareTo ) {
		executors.lock();
		try {
			variable Float meanFactor = 1.0;
			variable Float minDifference = -1.0;
			variable Executor? ret = null;
			variable Executor? next = executors.head;
			while ( exists n = executors.nextActive( next ) ) {
				next = n.next;
				meanFactor = n.loadFactor - factorToCompareTo;
				if ( meanFactor < 0.0 ) { meanFactor = -meanFactor; }
				if ( minDifference < 0.0 ) {
					minDifference = meanFactor;
					ret = n;
				}
				else if ( meanFactor < minDifference ) {
					minDifference = meanFactor;
					ret = n;
				}
			}
			return ret;
		}
		finally { executors.unlock(); }
	}
	
	
	Executor createExecutorOnThread( SingleThread thread )
			=> thread.addExecutor( Executor( signalEmpty, sampleCapacity ) );
	
	"creates new executor"
	shared Processor createExecutor() {
		if ( threads.empty ) {
			"impossible to create started thread"
			assert( exists thread = createThread() );
			return createExecutorOnThread( thread );
		}
		else {
			"at least one thread has to be existed"
			assert( exists thread = findLowestGradeThread() );
			if ( thread.loadLevel != LoadLevel.highLoadLevel ) {
				return createExecutorOnThread( thread );
			}
			else if ( exists newThread = createThread() ) {
				return createExecutorOnThread( newThread );
			}
			else { return createExecutorOnThread( thread ); }
		}
	}
	
	
	"closes all threads and executors"
	shared void close() {
		monitor.removeCounter( monitored.numberOfThreads );
		threads.lock();
		try {
			variable SingleThread? next = threads.head;
			while ( exists n = threads.nextActive( next ) ) {
				next = n.next;
				n.complete();
			}
			numberOfThreads.reset();
		}
		finally { threads.unlock(); }
	}
	
	
	"moves one executor from thread `from` to thread `to`"
	void moveExecutor( SingleThread from, SingleThread to ) {
		TwoWayList<Executor> executors = from.executors;
		// extract executor from thread and assign it to threadToMoveTo
		if ( executors.size == 2 ) {
			// try to move executor with lowest load factor to another thread
			if ( exists lowest = lowestGradeExecutor( executors ) ) { to.addExecutor( lowest ); }
		}
		else {
			// try to move accidental executor to another thread
			// accidental executor is selected as executor with the most near load level to
			// `thread.lastLoadFactor` - which is mainly accidental
			if ( exists accidental = nearFactorExecutor( executors, from.lastLoadFactor ) ) {
				to.addExecutor( accidental );
			}
		}
	}
	
	shared actual void optimize( SingleThread thread ) {
		if ( optimizationLock.tryLock() ) { 
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
								TwoWayList<Executor> executors = thread.executors;
								variable Executor? next = executors.head;
								while ( exists n = executors.nextActive( next ) ) {
									next = n.next;
									lowest.addExecutor( n );
								}
								removeThread( thread );
						 	}
						}
					}
					else if ( level == LoadLevel.highLoadLevel ) {
						// try to unload thread
						if ( thread.executors.size > 1 ) {
							// thread to assign executor to
							if ( exists lowest = findLowestGradeThreadExcept( thread ) ) {
								if ( lowest.loadLevel != LoadLevel.highLoadLevel ) { moveExecutor( thread, lowest ); }
								else if ( exists th = createThread() ) { moveExecutor( thread, th ); }
							}
							else if ( exists th = createThread() ) { moveExecutor( thread, th ); }
						}
					}
				}
			}
			catch ( Throwable err ) {}
			finally { optimizationLock.unlock(); }
		}
		
	}
	
}

