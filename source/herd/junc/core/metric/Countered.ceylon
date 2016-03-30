import herd.junc.api.monitor {
	Counter,
	CounterMetric
}

import java.util.concurrent.atomic {
	AtomicLong
}


"counter implementation"
by( "Lis" )
class Countered( shared actual String name ) satisfies CounterMetric & Counter
{
	
	AtomicLong atomic = AtomicLong( 0 );
	
	
	"returns current counting value"
	shared actual Integer measure() => atomic.get();
	
	shared actual void decrement( Integer on ) => atomic.addAndGet( -on );
	shared actual void increment( Integer on ) => atomic.addAndGet( on );
	shared actual void reset( Integer val ) => atomic.set( val );
	
}
