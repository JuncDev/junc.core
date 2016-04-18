
"_Junc_ core module.  
 Intended to start and operate _Junc_.  
 
 On _Junc_ API details see `module herd.junc.api`.
 
 #### Features.
 
 * Thread management.
 	* Automatic thread management by tracks load level.  
 	* Distribution tracks by threads to obtain optimal load level.
 	* Creating new threads if load level is high but no more than limited number.
 	* Removing threads if load level is low.
 * Station and serices management.
 	* Deploying and undeploying stations.
 	* Configurabality - you deploy only that stations you need.
 	* _Services_, _workshops_ and _connectors_ registering and unregistering.
 	* Establishing connections to registered services.
 	* Closing all connections, registered _services_, _workshops_ and _connectors_ when station is undeploying.
 * Local _workshop_ and _connector_.
 	* Provide registration of local services and connection to using `ServiceAddress` address. 
 	* Any type of send / received data may be used.
 * Monitoring.
 	* `Counter` of total number of deployed stations with name 'junc.core.stations' .
 	* `Counter` of number of currently executed threads with name 'junc.core.number of threads'.
 	* For each executed thread:
 		* `Average` of thread load level (value from 0.0 to 1.0) with name
 		  'junc.core.thread._thread ID_.load level'.
 		* `Average` of thread execution queue size per execution loop
 		  (number of functions in execution queue) with name
 		  'junc.core.thread._thread ID_.size of queue per loop'.
 	* Each local service provides monitoring of:
 		* `Counter` of number of connections with name 'service address.number of sockets'.
 		* `Meter` of connection rate per second with name 'service address.connection rate'.
 
 
 #### Usage.
 
 		startJuncCore(
 			JuncOptions { ... }
 		).onComplete (
 			(Railway railway) {
 				railway.deployStation(SomeStation(...));
 				...
 			}
 		);
 
 "
by( "Lis" )
native( "jvm" )
module herd.junc.core "0.1.0" {
	import ceylon.collection "1.2.2";
	shared import java.base "8";
	shared import herd.junc.api "0.1.0";
}
