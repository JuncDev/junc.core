import herd.junc.api {
	Station,
	Promise,
	Registration,
	Context
}
import herd.junc.api.monitor {
	MetricWriter,
	LogWriter
}


"
 `Railway` is passed to _Junc_ start listener and provides:
 * deploys stations
 * adds log and metric writers
 * stops the _Junc_
 "
by( "Lis" )
shared interface Railway
{
	"Deploys new station.  
	 Returns promise on specified ([[responseContext]]) or on station context
	 and resolved with registration to stop deployed station."
	shared formal Promise<Registration> deployStation (
		"Station to be deployed."
		Station station,
		"Context on which returned promise has to operate on (if `null` deployed station context is used)."
		Context? responseContext = null
	 );
	
	"Adds log writer.  Returns registration to remove added log writer."
	shared formal Registration addLogWriter( LogWriter logWriter );
	
	"Adds metric writer.  Returns registration to remove added metric writer."
	shared formal Registration addMetricWriter( MetricWriter metricWriter );
	
	"Forces writing metric.  May not be called manually since called by timer."
	shared formal void forceMetricWriting();
	
	"Stops the _Junc_."
	shared formal void stop();
}
