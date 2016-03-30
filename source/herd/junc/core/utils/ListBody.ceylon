

"list item whih contains just body"
by( "Lis" )
shared class ListBody<Body>( "item body - information field" shared Body body )
	extends ListItem<ListBody<Body>>()
{}


"helper function to call if body is function"
by( "Lis" )
shared void callBody( ListBody<Anything()> item ) {
	try { item.body(); }
	catch ( Throwable err ) {}
}
