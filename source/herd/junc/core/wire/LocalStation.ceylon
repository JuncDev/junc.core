import herd.junc.api {
	Promise,
	JuncTrack,
	Junc,
	Station,
	Registration
}
import herd.junc.core.metric {
	Monitoring
}


"Station which creates [[LocalService]] and initialize monitoring on its own track."
see( `class LocalService` )
by( "Lis" )
shared class LocalStation (
	"Selecting one service from a list when connection to be established." ServiceSelector selector,
	"Monitor station initializes and uses." Monitoring monitor
)
		satisfies Station
{
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {
		monitor.useTrack( track );
		value connector = LocalConnector( track.context, selector, junc );
		return track.registerWorkshop( connector ).and<Object, Registration> (
			track.registerConnector( connector ),
			( Registration val, Registration otherVal ) {
				return track.context.resolvedPromise( this );
			}
		);
	}
	
}
