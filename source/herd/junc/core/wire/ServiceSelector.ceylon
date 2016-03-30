
"Selecting one of [[ConnectedJuncService]] from a given list."
by( "Lis" )
shared interface ServiceSelector
{
	"Selects just one service from a list."
	shared formal ConnectedJuncService<FromService, ToService> select<FromService, ToService>(
		"Noempty sequence of services to select one from."
		[ConnectedJuncService<FromService, ToService>+] list
	);
}
