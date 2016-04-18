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
	
	"Factor applied to number of system cores (processors) to calculate maximum allowed number of threads."
	shared Float coreFactor = 1.5,
	
	"Period in event loop cycles used to perform _tracks_ optimization.
	 This means the _Junc_ optimizes or redistributes tracks over threads
	 each `optimizationPeriodInCycles` event loop cycle."
	shared Integer optimizationPeriodInCycles = 20,
	
	"Time limit in milliseconds used in load calculations.  
	 If averaged process time is:  
	 * Less with some tolerance the track is at low load level.  
	 * Close to `timeLimit` the track is at middle load level.  
	 * Greater with some tolerance the track is at high load level.  
	 "
	shared Integer timeLimit = 200
	
)
{}
