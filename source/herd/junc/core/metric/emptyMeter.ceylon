import herd.junc.api.monitor {
	Meter
}


"Meter which do nothing"
by( "Lis" )
shared object emptyMeter satisfies Meter
{
	shared actual void tick( Integer n ) {}
}