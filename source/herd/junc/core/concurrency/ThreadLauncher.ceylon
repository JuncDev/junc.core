import herd.junc.api.monitor {
	Monitor
}
import java.lang {
	Thread
}
import ceylon.collection {
	ArrayList
}


"Launches new thread."
see( `class SingleThread` )
by( "Lis" )
class ThreadLauncher (
	"Converts load factor to grade." LoadGrader grader,
	"Time limit used in load calculations." Integer timeLimit,
	"Factor used in flow averaging." Float meanFactor,
	"Optimization is run every `loopsForOptimization`." Integer loopsForOptimization,
	"Optimizing thread executors." ThreadOptimizer optimizer,
	"Monitoring system." Monitor monitor	
)
	extends Thread()
{
	
	ArrayList<Anything(SingleThread)> callbacks = ArrayList<Anything(SingleThread)>();
	
	"Adds callback called when thread is started."
	shared void addCallback( Anything(SingleThread) callback ) => callbacks.add( callback );
	
	
	shared actual void run() {
		SingleThread st = SingleThread (
			Thread.currentThread().id, grader, timeLimit, meanFactor, loopsForOptimization, optimizer, monitor
		);
		for ( callback in callbacks ) {
			callback( st );
		}
		st.run();
	}
	
}
