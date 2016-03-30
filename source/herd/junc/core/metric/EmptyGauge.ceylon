import herd.junc.api.monitor {
	Gauge
}


"gauge which do nothing"
by( "Lis" )
shared class EmptyGauge<T>() satisfies Gauge<T>
{
	shared actual void put( T val ) {}
}
