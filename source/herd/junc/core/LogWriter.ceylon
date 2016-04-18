import herd.junc.api.monitor {

	Priority
}


"A something capable to write a log."
see( `function Railway.addLogWriter` )
by( "Lis" )
shared interface LogWriter
{
	"Writes a log message."
	shared formal void writeLogMessage (
		"Identifier of the item which writes this log message." String identifier,
		"Priority of the log message." Priority priority,
		"Log message." String message,
		"Optional `Throwable` which may cause this log message." Throwable? throwable = null
	);
}
