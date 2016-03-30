import herd.junc.api.monitor {
	AverageMetric,
	Average
}

import java.util.concurrent.atomic {

	AtomicReference
}


"average implementation"
by( "Lis" )
class Averaged( shared actual String name ) satisfies AverageMetric & Average
{
	
	class Mean (
		shared Integer count = 0,
		shared Float mean = 0.0	
	)
			extends Object ()
	{
		shared Mean add( Float val ) {
			Integer c = count + 1;
			return Mean( c, mean + ( val - mean ) / c );
		}
		
		shared actual Boolean equals(Object that) {
			if (is Mean that) {
				return count==that.count && 
						mean==that.mean;
			}
			else {
				return false;
			}
		}
		shared actual Integer hash => 31*count + mean.hash;	
	}
	
	AtomicReference<Mean> atomicMean = AtomicReference<Mean>( Mean() );
	
	shared actual Float measure() => atomicMean.getAndSet( Mean() ).mean;
	
	shared actual void sample( Float val ) {
		variable Mean current = atomicMean.get();
		variable Mean next = current.add( val );
		while ( !atomicMean.compareAndSet( current, next ) ) {
			current = atomicMean.get();
			next = current.add( val );
		}
	}
	
}
