
"Dispatching messages."
by( "Lis" )
shared interface Dispatcher<Item>
{
	
	"Dispatches error message."
	shared formal void dispatchError( Throwable reason );
	
	"Dispatches close message."
	shared formal void dispatchClose();
	
	"Dispatches significant message."
	shared formal void dispatchMessage<SubItem>( SubItem message ) given SubItem satisfies Item;
}
