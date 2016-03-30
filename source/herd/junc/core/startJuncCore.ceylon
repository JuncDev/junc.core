import herd.junc.api {
	Promise,
	Station,
	Registration,
	Context
}
import herd.junc.api.monitor {
	LogWriter,
	MetricWriter,
	monitored
}
import herd.junc.core.concurrency {
	ContextManager,
	LoadGraderByBounds
}
import herd.junc.core.metric {
	Monitoring
}
import herd.junc.core.wire {
	StationManager,
	SelectServiceBySockets,
	LocalStation
}


"Starts _Junc_ core.  
 Returns promise resolved with [[Railway]], which can be used to deploy stations and also to stops the junc.
 It is recommened to deploy stations using [[Railway]] only to create an initial configuration of the application.
 "
by( "Lis" )
shared Promise<Railway> startJuncCore( "_Junc_ options." JuncOptions options = JuncOptions() ) {
	
// default parameters
	
	Float coreFactor = if ( options.coreFactor > 0.0 ) then options.coreFactor else 0.0;
	
	Integer averagingPeriodInCycles =
			if ( options.optimizationPeriodInCycles > 0 )
			then options.optimizationPeriodInCycles
			else 500;
	
	Float controlPersent =	if ( options.controlPersent > 0.0 && options.controlPersent < 1.0 )
							then options.controlPersent else 0.02;
	
// monitor
	Monitoring monitor = Monitoring( options.monitorPeriod * 1000, options.logPriority );

// context / thread manager
	ContextManager contextManager = ContextManager( coreFactor, controlPersent,
		LoadGraderByBounds( 0.40, 0.30, 0.80, 0.70 ), averagingPeriodInCycles, monitor );

// station manager and local service provider / connector
	StationManager stationManager = StationManager( contextManager, monitor, 10 );
	value local = LocalStation( SelectServiceBySockets(), monitor );

// deploy local station	
	return stationManager.deployStation (
		local, null
	).map (
		( Anything obj ) {
			return object satisfies Railway {
				shared actual Promise<Registration> deployStation( Station station, Context? responseContext )
					=> stationManager.deployStation( station, responseContext );
			
				shared actual Registration addLogWriter( LogWriter logWriter )
					=> monitor.addLogWriter( logWriter );
			
				shared actual Registration addMetricWriter( MetricWriter metricWriter )
					=> monitor.addMetricWriter( metricWriter );
			
				shared actual void forceMetricWriting() {
					if ( stationManager.running ) {
						monitor.writeMetrics();
					}
				}
			
				shared actual void stop() {
					if ( stationManager.running ) {
						monitor.logInfo( monitored.core, "junc is stopped" );
						stationManager.stop();
						contextManager.close();
					}
				}
			};
		}
	);
	
}
