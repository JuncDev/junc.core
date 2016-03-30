import herd.junc.api {
	Registration
}

import java.util.concurrent.atomic {
	AtomicReference
}


"empty registration"
by( "Lis" )
shared object emptyRegistration satisfies Registration
{
	shared actual void cancel() {}	
}


"regstration referenced on another one"
by( "Lis" )
shared class RegistrationRef( Registration initial = emptyRegistration )
		extends Reference<Registration>( initial ) satisfies Registration
{
	
	shared actual void cancel() => getAndSet( emptyRegistration ).cancel();
	
	
	"object which redirects [[Registration]] to this"
	shared object immutable satisfies Registration {
		shared actual void cancel() => outer.cancel();
	}
	
}


"list of registration:
 * cancels all in the list and clears list after canceling
 "
by( "Lis" )
shared class RegistrationList( {Registration*} registrations ) satisfies Registration
{
	
	AtomicReference<{Registration*}?> registrationItems = AtomicReference<{Registration*}?>( registrations );
	
	shared actual void cancel() {
		if ( exists l = registrationItems.getAndSet( null ) ) {
			for ( reg in l ) { reg.cancel(); }
		}
	}
	
}
