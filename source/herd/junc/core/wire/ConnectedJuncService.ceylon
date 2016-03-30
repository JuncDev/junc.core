import herd.junc.api {
	JuncService,
	JuncSocket,
	Promise,
	Context,
	ServiceAddress
}


"_Junc_ service with connection capability."
by( "Lis" )
shared interface ConnectedJuncService<in From, in To> satisfies JuncService<From, To>
{
	
	shared formal actual ServiceAddress address;
	
	"Connects to the service.  
	 Returns promise on client context ([[clientContext]]) resolved with client socket or rejected if errors."
	shared formal Promise<JuncSocket<FromSocket, ToSocket>> connect<FromSocket, ToSocket> (
		"Context the client socket to work on." Context clientContext
	);
	
}
