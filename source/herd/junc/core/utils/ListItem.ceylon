

"stated item used in two way list"
see( `class TwoWayList`)
see( `class ListItemState`)
by( "Lis" )
shared class ListItem<List>()
	given List satisfies ListItem<List>
{
	
	"next item in the list or null if this item is the last"
	shared variable List? next = null;
	
	"previous item in the list or null if this item is the first"
	shared variable List? previous = null;
	
	"state from atomic reference"
	shared variable ListItemState state = stateAdding;
	
	"registration this item contains"
	shared RegistrationRef registration = RegistrationRef();
}
