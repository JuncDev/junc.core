import herd.junc.api.monitor {
	Average
}


"average which do nothing"
by( "Lis" )
shared object emptyAverage satisfies Average
{
	shared actual void sample( Float val ) {}
}
