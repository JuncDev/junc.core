import herd.junc.api.monitor {
	Monitor
}

import java.lang {
	Runtime,
	Runnable
}
import java.util.concurrent {
	Executors,
	ExecutorService
}


"Manages contexts within threads.
 Each thread may contain any number of context.  
 When new context (processor) created it is assigned to existing or new thread depending on loading.  
 Context may be reassigned to another thread if loading is high or low.
 Threads are managed automaticaly:
 * may be added but total number of threads is to be less than `coreFactor` `*` `Runtime.runtime.availableProcessors()`   
 * may be removed if loading is low  
 
 Load level is estimated using [[grader]]:  
 "
by( "Lis" )
shared class ContextManager
(
	"Factor on available core processor to estimate maximum possible threads.  
	 So maximum number of threads is `coreFactor` * `Runtime.runtime.availableProcessors()`."
	Float coreFactor,
	"Persents the controls may take from full execution time at middle load level."
	Float controlPersent,
	"Converts load factor to grade."
	LoadGrader grader,
	"Number of samples to calculate mean value."
	Integer sampleCapacity,
	"Monitor to store context metrics."
	Monitor monitor
)
		satisfies ProcessorFactory
{
	
	ThreadManager manager = ThreadManager( coreFactor, controlPersent, grader, sampleCapacity, monitor );
	
	ExecutorService blocked = Executors.newFixedThreadPool (
		if ( Runtime.runtime.availableProcessors() / 2 > 0 ) then Runtime.runtime.availableProcessors() / 2 else 1
	);
	
	
	"closes all threads and executors"
	shared void close() => manager.close();
	
	
	shared actual Processor createProcessor() => manager.createExecutor();
	
	shared actual Boolean overloaded => manager.overloaded;
	
	shared actual void executeBlocked( Runnable exec ) => blocked.execute( exec );
	
}
