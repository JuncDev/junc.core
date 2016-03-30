import herd.junc.api.monitor {

	Priority
}


"General _Junc_ options pushed to _Junc_ when starting."
by( "Lis" )
shared class JuncOptions (
	"Period in seconds at which monitoring is to be performed.  
	 If 0 or less, no monitoring is performed."
	shared Integer monitorPeriod = 0,
	
	"Log priority."
	shared Priority logPriority = Priority.info,
	
	"Factor applied to number of system cores (processors) to obtain maximum allowed number of threads."
	shared Float coreFactor = 1.5,
	
	"Period in event loop cycles used to perform _tracks_ optimization."
	shared Integer optimizationPeriodInCycles = 500,
	
	"Percents the control execution may take from full execution time at middle load level.  
	 To be greater than 0.0 and less than 1.0."
	shared Float controlPersent = 0.02
)
{}
