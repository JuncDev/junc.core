import herd.junc.api {

	JuncAddress
}

"Searches available connectors and workshops."
by( "Lis" )
interface ProviderSearcher
{
	"Returns connector by type."
	shared formal ConnectorAbs<From, To, Address>? getConnector<From, To, Address>() given Address satisfies JuncAddress;
	
	"Returns workshop by type."
	shared formal WorkshopAbs<From, To, Address>? getWorkshop<From, To, Address>() given Address satisfies JuncAddress;
}
