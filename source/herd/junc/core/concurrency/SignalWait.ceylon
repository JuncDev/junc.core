import java.util.concurrent {
	TimeUnit {
		milliseconds=\iMILLISECONDS
	}
}
import java.util.concurrent.locks {
	ReentrantLock,
	Condition
}


"Conditionning lock:
 * Call [[await]] and the thread will be locked until [[signal]] not called.
 * When [[signal]] is called the condition to be signaled and thread will acquire this lock.
 * [[signal]] just try to lock and returns immediately, it is supposed that is locked then
   awaiter is in process right now or another thread sends signal.
 "
by( "Lis" )
class SignalWait() satisfies Signal
{
	"Locker behind this lock."
	ReentrantLock locker = ReentrantLock();
	
	"Condition behind this lock."
	Condition condition = locker.newCondition();
	
	"`True` if was signaled but no await started and `false` if await has been unlocked."
	variable Boolean signaled = false;
	
	
	"Waits until condition signaled. 
	 If [[waitMilliseconds]] specified signals depending on what occurs early - time or signaling."
	see( `function signal` )
	shared void await (
		"Milliseconds to wait or <= 0 if unlimited." Integer waitMilliseconds = 0
	) {
		locker.lock();
		try {
			if ( !signaled ) {
				if ( waitMilliseconds > 0 ) { condition.await( waitMilliseconds, milliseconds ); }
				else { condition.await(); }
			}
			signaled = false;
		}
		finally { locker.unlock(); }
	}
	
	
	"Locks and when it is acquired signals that condition is satisfied."
	see( `function await` )
	shared actual void signal() {
		locker.lock();
		try { 
			if ( !signaled ) {
				signaled = true;
				condition.signal();
			}
		}
		finally { locker.unlock(); }
	}
	
}
