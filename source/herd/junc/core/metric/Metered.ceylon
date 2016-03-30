import herd.junc.api.monitor {
	Meter,
	MeterMetric
}

import java.util.concurrent.atomic {
	AtomicLong
}


by( "Lis" )
throws( `class AssertionError`, "`meanPeriodMilliSeconds` is less or eqaul to zero" )
class Metered (
	shared actual String name,
	"period in milliseconds used to averaging the meter" Integer meanPeriodMilliSeconds
)
		satisfies MeterMetric & Meter
{
	"period for meter averaging to be greater than zero"
	assert( meanPeriodMilliSeconds > 0 );
	
	variable Float lastValue = 0.0;
	variable Integer lastTime = system.milliseconds;
	AtomicLong tickCount = AtomicLong( 0 );
	
	
	"calculate meter value - to be called periodicaly to recalculate meter value"
	shared void calculate( "current time in milliseconds" Integer milliseconds ) {
		Integer delta = milliseconds - lastTime;
		if ( delta > 1 ) {
			Float d = 1.0 / ( delta + meanPeriodMilliSeconds );
			lastValue = d * tickCount.get() * 1000.0 + ( 1 - delta * d ) * lastValue;
			if ( !lastValue.finite ) { lastValue = 0.0; }
			tickCount.set( 0 );
			lastTime = milliseconds;
		}
	}
	
	
	shared actual Float measure() => lastValue;
	
	shared actual void tick( Integer n ) {
		if ( n > 0 ) { tickCount.addAndGet( n ); }
	}
	
}
