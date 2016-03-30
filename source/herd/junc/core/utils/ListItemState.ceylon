
"State of list item - one of adding, active, dismissed or alredy removed."
by( "Lis" )
shared abstract class ListItemState()
	of stateAdding | stateActive | stateDismissed | stateAlreadyRemoved
{}

shared object stateAdding extends ListItemState() {}
shared object stateActive extends ListItemState() {}
shared object stateDismissed extends ListItemState() {}
shared object stateAlreadyRemoved extends ListItemState() {}
