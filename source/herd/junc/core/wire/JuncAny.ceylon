import herd.junc.api {

	JuncSocket,
	JuncService
}


"Socket - with any emitter / publisher types."
by( "Lis" )
interface JuncSocketAny => JuncSocket<Nothing, Nothing>;

"Service with any send / receive types."
by( "Lis" )
interface JuncServiceAny => JuncService<Nothing, Nothing>;

"Service with any send / receive types and connection capability."
by( "Lis" )
interface ConnectedJuncServiceAny => ConnectedJuncService<Nothing, Nothing>;

