import herd.junc.api.monitor {
	Counter
}


"Counter which do nothing."
by( "Lis" )
shared object emptyCounter satisfies Counter 
{
	
	shared actual void decrement(Integer on) {}
	
	shared actual void increment(Integer on) {}
	
	shared actual void reset(Integer val) {}
}
