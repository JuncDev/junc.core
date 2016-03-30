import herd.junc.core.utils {
	Reference
}


"signalling interface - sends signal somewhere"
by( "Lis" )
interface Signal
{
	
	"sends signal"
	shared formal void signal();
}

"mutable reference to another signal"
by( "Lis" )
class SignalReference( Signal initial ) extends Reference<Signal>( initial ) satisfies Signal
{
	shared actual void signal() => reference.signal();
}

object signalEmpty satisfies Signal
{
	shared actual void signal() {}
}
