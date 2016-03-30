import herd.junc.api {
	Junc,
	JuncTrack,
	Station,
	Promise
}


class SimpleStation() satisfies Station
{
	variable Junc? juncCache = null;
	variable JuncTrack? trackCache = null;
	
	shared Junc? junc => juncCache;
	shared JuncTrack? track => trackCache;
	
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {
		juncCache = junc;
		trackCache = track;
		return track.context.resolvedPromise( this );
	}
	
}
