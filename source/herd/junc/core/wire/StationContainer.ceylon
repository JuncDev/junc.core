import herd.junc.core.utils {

	TwoWayList
}
import herd.junc.api {

	JuncAddress
}


"Stores stations."
by( "Lis" )
class StationContainer() satisfies ProviderSearcher
{
	"Stations list."
	shared TwoWayList<StationRegister> stations = TwoWayList<StationRegister>();
	
	
	shared actual ConnectorAbs<From, To, Address>? getConnector<From, To, Address>()
			given Address satisfies JuncAddress
	{
		stations.lock();
		try {
			variable StationRegister? h = stations.head;
			while ( exists n = h ) {
				if ( exists ret = n.getConnector<From, To, Address>() ) {
					return ret;
				}
				h = n.next;
			}
			return null;
		}
		finally {
			stations.unlock();
		}
	}
	
	shared actual WorkshopAbs<From, To, Address>? getWorkshop<From, To, Address>()
			given Address satisfies JuncAddress
	{
		stations.lock();
		try {
			variable StationRegister? h = stations.head;
			while ( exists n = h ) {
				if ( exists ret = n.getWorkshop<From, To, Address>() ) {
					return ret;
				}
				h = n.next;
			}
			return null;
		}
		finally {
			stations.unlock();
		}
	}
	
	
}
