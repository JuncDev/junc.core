
"Optimizing thread executors in the pool."
by( "Lis" )
interface ThreadOptimizer
{
	"Optimizes specified thread."
	shared formal void optimize (
		"Thread to be optimazied." SingleThread thread,
		"`True` if optimization may be skipped if another optimization is currently processed." Boolean skipWaiting
	);
}
