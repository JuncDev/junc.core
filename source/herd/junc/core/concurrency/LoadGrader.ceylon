import herd.junc.api {
	LoadLevel
}

"grades load factor to load grade - low, middle, high"
by( "Lis" )
shared interface LoadGrader
{
	"grades the factor"
	shared formal LoadLevel grade( "factor to define grade for" Float factor, "current load grade" LoadLevel current );
}
