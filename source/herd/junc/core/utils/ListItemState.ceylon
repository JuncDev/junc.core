
"State of list item - one of adding, active, dismissed or alredy removed."
by( "Lis" )
shared class ListItemState
	of stateAdding | stateActive | stateDismissed | stateAlreadyRemoved
{

	shared new stateAdding {}
	shared new stateActive {}
	shared new stateDismissed {}
	shared new stateAlreadyRemoved {}

}
