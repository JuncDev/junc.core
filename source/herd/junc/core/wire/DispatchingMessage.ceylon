

"Message which may be dispatched."
by( "Lis" )
abstract class DispatchingMessage<Item>()
{
	"Dispatches the message to dispatcher."
	shared formal void dispatch( Dispatcher<Item> dispatcher );
	
// organizing messages list
	shared variable DispatchingMessage<Item>? next = null;
	shared variable DispatchingMessage<Item>? prev = null;
}


"Significant message."
by( "Lis" )
class SignificantMessage<Item, SubItem>( SubItem message )
		extends DispatchingMessage<Item>()
		given SubItem satisfies Item
{	
	shared actual void dispatch( Dispatcher<Item> dispatcher ) {
		dispatcher.dispatchMessage<SubItem>( message );
	}
}



"Dispatches close message."
by( "Lis" )
class CloseMessage<Item>() extends DispatchingMessage<Item>() {
	shared actual void dispatch( Dispatcher<Item> dispatcher ) {
		dispatcher.dispatchClose();
	}
}


"Dispatches error message."
by( "Lis" )
class ErrorMessage<Item>( Throwable reason ) extends DispatchingMessage<Item>() {
	shared actual void dispatch( Dispatcher<Item> dispatcher ) {
		dispatcher.dispatchError( reason );
	}
}


