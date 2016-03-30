import herd.junc.api.monitor {
	Gauge,
	GaugeMetric
}

import java.util.concurrent.atomic {
	AtomicReference
}


interface GaugeStore<out Tout, in Tin> satisfies GaugeMetric<Tout>
{
	shared formal Gauge<Tin> gauge;
}

by( "Lis" )
class Gauged<T>( shared actual String name ) satisfies GaugeStore<T, T>
{
	
	AtomicReference<T> atomic = AtomicReference<T>( null ); 
	
	shared actual T? measure() => atomic.get();
	
	shared actual object gauge satisfies Gauge<T> {
		shared actual void put( T val ) => atomic.set( val );	
	}
	
}
