import herd.junc.core.utils {

	ListBody,
	DualList
}
import herd.junc.api {

	WorkshopDescriptor,
	Context,
	ServiceDescriptorAny,
	JuncService,
	Promise,
	Registration,
	JuncAddress,
	Workshop,
	ServiceDescriptor,
	Publisher,
	JuncEvent,
	WorkshopRemovedEvent,
	ServiceAddedEvent,
	ServiceClosedEvent,
	Message
}
import ceylon.collection {

	HashMap
}
import herd.junc.api.monitor {

	Monitor,
	monitored
}
import java.util.concurrent.locks {

	ReentrantLock
}


"Wrokshop storage."
by( "Lis" )
class WorkshopImpl<From, To, Address> (
	"Backed workshop." Workshop<From, To, Address> workshop,
	"Context workshop works on." Context workshopContext,
	"Publishing workshop events." Publisher<JuncEvent> events,
	"Used monitor." Monitor monitor
)
		satisfies WorkshopAbs<From, To, Address>
		given Address satisfies JuncAddress
{
	
	ReentrantLock providedLock = ReentrantLock();
	HashMap<ServiceBoxAny, DualList<JuncServiceAny>> providedServices = HashMap<ServiceBoxAny, DualList<JuncServiceAny>>();

	
	"Returns total number of service with the same type and address."
	Integer removeIfEmpty<Send, Receive>( ServiceBox<Send, Receive, Address> box ) {
		providedLock.lock();
		try {
			if ( exists list = providedServices.get( box ) ) {
				if ( list.empty ) {
					providedServices.remove( box );
					return 0;
				}
				else {
					return list.size;
				}
			}
			else {
				return 0;
			}
		}
		finally {
			providedLock.unlock();
		}
	}
	
	"Stores added service."
	void storeService<Send, Receive>( Address address, JuncService<Send, Receive> service )() {
		providedLock.lock();
		try {
			ServiceBox<Send, Receive, Address> box = ServiceBox<Send, Receive, Address>( address );
			Registration reg;
			Integer totalServices;
			// add service to the list
			if ( exists list = providedServices.get( box ) ) {
				reg = list.addItem( service );
				totalServices = list.size;
			}
			else {
				DualList<JuncServiceAny> list = DualList<JuncServiceAny>();
				reg = list.addItem( service );
				providedServices.put( box, list );
				totalServices = 1;
			}
			
			// initialize service close event
			service.onClose (
				() {
					reg.cancel();
					Integer remainServices = removeIfEmpty( box );
					events.publish( ServiceClosedEvent( box.getDecriptor( remainServices ) ) );
					// log to monitor
					monitor.logInfo (
						monitored.core,
						"service with address ```service.address``` has been closed"
					);
				}
			);
			
			// log to monitor
			monitor.logInfo (
				monitored.core,
				"service with address ```service.address``` has been successfully registered"
			);
			
			// raise service added event
			events.publish( ServiceAddedEvent( box.getDecriptor( totalServices ) ) );
		}
		finally {
			providedLock.unlock();
		}
	}
	
	
	"Closes service."
	void closeService( ListBody<JuncServiceAny> service ) => service.registration.cancel();		
	
	
	shared actual void close() {
		providedLock.lock();
		try {
			for ( sList in providedServices.items ) {
				sList.forEachActive( closeService );
				sList.clear();
			}
			providedServices.clear();
			events.publish (
				WorkshopRemovedEvent<From, To, Address> (
					object satisfies WorkshopDescriptor<From, To, Address> {
						shared actual {ServiceDescriptor<Send, Receive, Address>*} services<Send, Receive>()
								given Send satisfies From
								given Receive satisfies To
								=> {};
					}
				)
			);
		}
		finally {
			providedLock.unlock();
		}
	}
	
	
	void logRegistrationError( JuncAddress address, Throwable err ) {
		monitor.logError (
			monitored.core,
			"when tries to register service with address ```address```",
			err
		);
	}
	
	
	shared actual Promise<Message<JuncService<Send, Receive>, Null>> provideService<Send, Receive> (
		Address address, Context context
	)
			given Send of From
			given Receive of To
	{
		return workshopContext.executeWithPromise (
			unflatten( workshop.provideService<Send, Receive> ),
			[address, context]
		).map (
			( Message<JuncService<Send, Receive>, Null> message ) {
				return MessageWrapper (
					message, workshopContext, storeService( address, message.body ), null
				);
			},
			context
		).onError( ( Throwable err ) => logRegistrationError( address, err ) );
	}
	
	
	shared actual WorkshopDescriptor<From, To, Address> descriptor {
		providedLock.lock();
		try {
			ServiceDescriptorAny[] listOfServices = [for ( key->item in providedServices ) key.getDecriptor( item.size ) ];
			return object satisfies WorkshopDescriptor<From, To, Address> {
				shared actual {ServiceDescriptor<Send, Receive, Address>*} services<Send, Receive>()
						given Send satisfies From
						given Receive satisfies To
						=> listOfServices.narrow<ServiceDescriptor<Send, Receive, Address>>();
			};
		}
		finally {
			providedLock.unlock();
		}
	}
	
}
