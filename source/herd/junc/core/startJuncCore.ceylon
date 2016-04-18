import herd.junc.api {
	Promise,
	Station,
	Registration,
	Context
}
import herd.junc.api.monitor {
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
	
	Integer optimizationPeriodInCycles =
			if ( options.optimizationPeriodInCycles > 0 )
			then options.optimizationPeriodInCycles
			else 20;
	
	Integer timeLimit = if ( options.timeLimit > 1 ) then options.timeLimit else 1;
	
	Float meanFactor = 0.05;
	
// monitor
	Monitoring monitor = Monitoring( options.monitorPeriod * 1000, options.logPriority );

// context / thread manager
	ContextManager contextManager = ContextManager (
		coreFactor,
		LoadGraderByBounds( 0.35, 0.25, 0.75, 0.65 ), optimizationPeriodInCycles,
		timeLimit, meanFactor,
		monitor
	);

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
