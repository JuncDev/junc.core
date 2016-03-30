import herd.junc.core.utils {

	ListBody,
	DualList
}
import herd.junc.api {

	Context,
	JuncSocket,
	Promise,
	JuncAddress,
	ConnectorDescriptor,
	Connector,
	Publisher,
	JuncEvent,
	ConnectorRemovedEvent
}


"Connector storage."
by( "Lis" )
class ConnectorImpl<From, To, Address> (
	Connector<From, To, Address> connector,
	Context connectorContext,
	Publisher<JuncEvent> events
)
		satisfies ConnectorAbs<From, To, Address>
		given Address satisfies JuncAddress
{
	
	class ConnectionProcessor<Send, Receive> (
		Address address, Context clientContext
	)
			given Send of From
			given Receive of To
	{
		shared Promise<JuncSocket<Send, Receive>> process( Connector<From, To, Address> connector )
				=> connector.connect<Send, Receive>( address, clientContext );
	}
	
	
	DualList<JuncSocketAny> sockets = DualList<JuncSocketAny>();
	
	void addSocket( JuncSocketAny socket )
			=> socket.onClose( sockets.addItem( socket ).cancel );
	
	void closeSocket( ListBody<JuncSocketAny> socket ) => socket.body.close();
	
	shared actual ConnectorDescriptor<From, To, Address> descriptor = 
			object satisfies ConnectorDescriptor<From, To, Address> {};
	
	shared actual void close() {
		sockets.forEachActive( closeSocket );
		sockets.clear();
		events.publish( ConnectorRemovedEvent( descriptor ) );
	}
	
	shared actual Promise<JuncSocket<Send, Receive>> connect<Send, Receive> (
		Address address, Context clientContext
	)	
			given Send of From
			given Receive of To
	{
		return connectorContext.executeWithPromise (
			ConnectionProcessor<Send, Receive>( address, clientContext ).process,
			connector
		).onComplete( addSocket ).contexting( clientContext );
	}
	
}

