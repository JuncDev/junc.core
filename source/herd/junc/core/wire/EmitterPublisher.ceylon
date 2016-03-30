import herd.junc.api {
	Emitter,
	Publisher,
	Registration,
	Context
}
import herd.junc.core.utils {
	emptyRegistration,
	RegistrationList,
	DualList,
	ListBody,
	callBody
}

import java.util.concurrent.atomic {
	AtomicBoolean,
	AtomicReference
}


"Base emitter and publisher, which publishes to self."
by( "Lis" )
class EmitterPublisher<Item> (
	"Context to execute emissions." Context context,
	"Number of messages stored while not listener added." Integer numberOfStoredMessages
)
		satisfies Dispatcher<Item>
{
	"Error handlers."
	DualList<Anything(Throwable)> errorHandlers = DualList<Anything(Throwable)>(); 
	
	"Close handlers."
	DualList<Anything()> closeHandlers = DualList<Anything()>();
	
	"Proxies to another publisher."
	DualList<Publisher<Item>> proxies = DualList<Publisher<Item>>();  
	
	"Data handlers. `FunctionWrapper` improves `is` performance."
	DualList<FunctionWrapper<Nothing>> dataHandlers = DualList<FunctionWrapper<Nothing>>();
	
	"Exact type data handlers."
	DualList<Anything(Item)> exactHandlers = DualList<Anything(Item)>();
	
	"`True` if has handlers."
	Boolean hasHandlers => (!dataHandlers.empty) || (!exactHandlers.empty) || (!proxies.empty);
	
	
	"`True` if running and `false` if closed - to prevent message publishing."
	AtomicBoolean runningAtomic = AtomicBoolean( true );

	shared Boolean running => runningAtomic.get();
	
	
	"Messages to be processed from next call [[dispatchEvents]]."
	AtomicReference<DispatchingMessage<Item>> msgQueue = AtomicReference<DispatchingMessage<Item>>();
	
	"Message dispatcher is running on context now."
	AtomicBoolean dispatching = AtomicBoolean( false );
	
	
	"Proxies this publisher to another one."
	shared Registration addProxy( Publisher<Item> proxy ) => proxies.addItem( proxy );
	
	"Dispatches messages to receivers."
	void dispatchEvents() {
		dispatching.set( false );
		variable DispatchingMessage<Item>? message = msgQueue.getAndSet( null );
		// messages are put in reversed order, so iterate the list to put them in correct order firstly
		variable DispatchingMessage<Item>? head = message;
		while ( exists msg = message ) {
			if ( exists next = msg.next ) {
				next.prev = msg;
			}
			else {
				head = msg;
			}
			message = msg.next;
		}
		// process messages in correct order
		while ( exists msg = head ) {
			msg.dispatch( this );
			head = msg.prev;
		}
	}
	
	shared actual void dispatchError( Throwable reason ) {
		errorHandlers.lock();
		variable ListBody<Anything(Throwable)>? next = errorHandlers.head;
		while ( exists handlerCell = errorHandlers.nextActive( next ) ) {
			next = handlerCell.next;
			try { handlerCell.body( reason ); }
			catch ( Throwable err ) {}
		}
		errorHandlers.unlock();
		
		proxies.lock();
		variable ListBody<Publisher<Item>>? nextPublisher = proxies.head;
		while ( exists proxyCell = proxies.nextActive( nextPublisher ) ) {
			nextPublisher = proxyCell.next;
			proxyCell.body.error( reason );
		}
		proxies.unlock();
	}
	
	shared actual void dispatchClose() {
		if ( runningAtomic.compareAndSet( true, false ) ) {
			errorHandlers.clear();
			exactHandlers.clear();
			dataHandlers.clear();
			closeHandlers.forEachActive( callBody );
			closeHandlers.clear();
			
			proxies.lock();
			variable ListBody<Publisher<Item>>? nextPublisher = proxies.head;
			while ( exists proxyCell = proxies.nextActive( nextPublisher ) ) {
				nextPublisher = proxyCell.next;
				proxyCell.body.close();
			}
			proxies.unlock();
			proxies.clear();
		}
	}
	
	shared actual void dispatchMessage<SubItem>( SubItem message )
			given SubItem satisfies Item
	{
		exactHandlers.lock();
		variable ListBody<Anything(Item)>? exactNext = exactHandlers.head;
		while ( exists handlerCell = exactHandlers.nextActive( exactNext ) ) {
			exactNext = handlerCell.next;
			try { handlerCell.body( message ); }
			catch ( Throwable err ) {}
		}
		exactHandlers.unlock();
		
		
		dataHandlers.lock();
		variable ListBody<FunctionWrapper<Nothing>>? next = dataHandlers.head;
		while ( exists handlerCell = dataHandlers.nextActive( next ) ) {
			next = handlerCell.next;
			if ( is FunctionWrapper<SubItem> handler = handlerCell.body ) {
				try { handler.func( message ); }
				catch ( Throwable err ) {}
			}
		}
		dataHandlers.unlock();
		
		proxies.lock();
		variable ListBody<Publisher<Item>>? nextPublisher = proxies.head;
		while ( exists proxyCell = proxies.nextActive( nextPublisher ) ) {
			nextPublisher = proxyCell.next;
			proxyCell.body.publish<SubItem>( message );
		}
		proxies.unlock();
	}
		
	
	"Puts new message to queue and runs the queue processing if not yet started."
	void putMessageToQueue( DispatchingMessage<Item> msg ) {
		msg.next = msgQueue.getAndSet( msg );
		if ( hasHandlers ) {
			if ( dispatching.compareAndSet( false, true ) ) {
				context.execute( dispatchEvents );
			}
		}
		else {
			variable DispatchingMessage<Item>? message = msgQueue.get();
			variable Integer count = 0;
			while ( exists msgItem = message ) {
				count ++;
				if ( count > numberOfStoredMessages ) {
					if ( dispatching.compareAndSet( false, true ) ) {
						context.execute( dispatchEvents );
					}
					break;
				}
				message = msgItem.next;
			}
		}
	}
	
	
	"Puts 'significant' or data message to the queue."
	void putSignificantMessage<SubItem>( SubItem msg )
			given SubItem satisfies Item
	{
		if ( running ) {
			putMessageToQueue( SignificantMessage<Item, SubItem>( msg ) );
		}
	}


// Emiter and Publisher interfaces backed by this
	
	"Only emitter."
	shared object emitter satisfies Emitter<Item> {
		
		shared actual Registration onClose( Anything() close ) {
			if ( running ) {
				return closeHandlers.addItem( close );
			}
			else {
				context.execute( close );
				return emptyRegistration;
			}
		}
		
		shared actual Registration onData<SubItem>( Anything(SubItem) data ) given SubItem satisfies Item {
			if ( running ) {
				Registration ret;
				if ( is Anything(Item) data ) {
					ret = exactHandlers.addItem( data );
				}
				else {
					ret = dataHandlers.addItem( FunctionWrapper( data ) );
				}
				if ( msgQueue.get() exists ) {
					if ( dispatching.compareAndSet( false, true ) ) {
						context.execute( dispatchEvents );
					}
				}
				return ret;
			}
			else { return emptyRegistration; }
		}
		
		shared actual Registration onError( Anything(Throwable) error ) {
			if ( running ) { return errorHandlers.addItem( error ); }
			else { return emptyRegistration; }
		}
		
		shared actual Registration onEmit<SubItem> (
			Anything(SubItem) data, Anything(Throwable) error, Anything() close
		)  given SubItem satisfies Item
				=> RegistrationList( [ onData( data ), onError( error ), onClose( close ) ] );
		
	}
	
	"Only publisher."
	shared object publisher satisfies Publisher<Item> {
		shared actual Boolean closed => !running;
		shared actual void close() {
			if ( running ) {
				putMessageToQueue( CloseMessage<Item>() );
			}
		}
		shared actual void error( Throwable error ) {
			if ( running ) {
				putMessageToQueue( ErrorMessage<Item>( error ) );
			}
		}
		shared actual void publish<SubItem>( SubItem msg ) given SubItem satisfies Item
				=> outer.putSignificantMessage( msg );
	}
	
}
