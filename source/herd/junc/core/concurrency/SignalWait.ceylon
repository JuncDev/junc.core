import java.util.concurrent {
	TimeUnit {
		milliseconds=\iMILLISECONDS
	}
}
import java.util.concurrent.atomic {
	AtomicBoolean
}
import java.util.concurrent.locks {
	ReentrantLock,
	Condition
}


"conditionning lock:
 * call [[await]] and the thread will be locked until [[signal]] not called.
 * when [[signal]] is called the condition to be signaled and thread will acquire this lock
 * [[signal]] just try to lock and returns immediately, it is supposed that is locked then
   awaiter is in process right now or another thread sends signal
 "
by( "Lis" )
class SignalWait() satisfies Signal
{
	"locker behind this lock"
	ReentrantLock locker = ReentrantLock();
	
	"condition behind this lock"
	Condition condition = locker.newCondition();
	
	"`true` if was signaled but no await started and `false` if await has been unlocked"
	AtomicBoolean signaledAtomic = AtomicBoolean( false );
	
	
	"wait until condition signaled. 
	 If [[waitMilliseconds]] specified signals depending on what occurs early - time or signaling"
	see( `function signal` )
	shared void await (
		"milliseconds to wait or <= 0 if unlimited" Integer waitMilliseconds = 0
	) {
		locker.lock();
		try {
			if ( !signaledAtomic.get() ) {
				if ( waitMilliseconds > 0 ) { condition.await( waitMilliseconds, milliseconds ); }
				else { condition.await(); }
			}
			signaledAtomic.set( false );
		}
		finally { locker.unlock(); }
	}
	
	
	"Tries to lock and if it is acquired signals that condition is satisfied.  
	 If locked by another thread - do nothing and returns immediately"
	see( `function await` )
	shared actual void signal() {
		if ( signaledAtomic.compareAndSet( false, true ) ) {
			if ( locker.tryLock() ) {
				try { condition.signal(); }
				finally { locker.unlock(); }
			}
		}
	}
	
}
