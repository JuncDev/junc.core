import ceylon.collection {
	ArrayList
}

import herd.junc.api {
	Registration
}


"two eay list with given item type"
by( "Lis" )
shared class DualList<Body>() extends TwoWayList<ListBody<Body>>()
{
	
	"add item to the list"
	shared Registration addItem( Body item ) => addToList( ListBody( item ) );
	
	"process for each item in the list"
	shared void forEachBody( void process( Body body ) ) => forEachActive( ( ListBody<Body> l ) => process( l.body ) );
	
	"copy items to iterable"
	shared {Body*} copy() {
		ArrayList<Body> list = ArrayList<Body>();
		forEachActive( ( ListBody<Body> l ) => list.add( l.body ) );
		return list; 
	}
	
}