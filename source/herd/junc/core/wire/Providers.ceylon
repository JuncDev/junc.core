import herd.junc.api {

	JuncAddress,
	Workshop,
	Connector,
	ConnectorDescriptor,
	WorkshopDescriptor,
	ServiceDescriptor
}


"Workshop provider."
by( "Lis" )
interface WorkshopAbs<in From, in To, in Address> satisfies Workshop<From, To, Address>
		given Address satisfies JuncAddress
{
	"Closes this workshop and all provided services."
	shared formal void close();
	
	"Returns descriptor of this workshop."
	shared formal WorkshopDescriptor<From, To, Address> descriptor;
	
}

interface WorkshopAny => WorkshopAbs<Nothing, Nothing, Nothing>;


"Connector provider."
by( "Lis" )
interface ConnectorAbs<in From, in To, in Address> satisfies Connector<From, To, Address>
		given Address satisfies JuncAddress
{
	"Closes this connector and all provided connections."
	shared formal void close();
	
	"Returns descriptor of this connector."
	shared formal ConnectorDescriptor<From, To, Address> descriptor;
}

interface ConnectorAny => ConnectorAbs<Nothing, Nothing, Nothing>;


"Box to provide service descriptor."
by( "Lis" )
class ServiceBox<in From, in To> (
	shared JuncAddress address
)
		extends Object()
{
	
	Boolean compareTypes( ServiceBoxAny box ) => if ( is ServiceBox<From, To> box ) then true else false;
	
	shared ServiceDescriptor<From, To> getDecriptor( Integer totalNumber ) =>
			object satisfies ServiceDescriptor<From, To> {
				shared actual JuncAddress address => outer.address;
				shared actual Integer count => totalNumber;
			};

	
	shared actual Boolean equals( Object that ) {
		if ( is ServiceBoxAny that, address == that.address ) {
			return compareTypes( that ) && that.compareTypes( this );
		}
		else {
			return false;
		}
	}
	
	shared actual Integer hash => address.hash;
	
}

alias ServiceBoxAny => ServiceBox<Nothing, Nothing>;
