import herd.junc.api.monitor {
	Monitor
}


"optimizing thread executors in the pool"
by( "Lis" )
interface ThreadOptimizer
{
	"optimize specified thread"
	shared formal void optimize( SingleThread thread );
	
	"`true` if new thread can be added and `false` otherwise"
	shared formal Boolean extensible;
	
	"monitoring system"
	shared formal Monitor monitor;
}
