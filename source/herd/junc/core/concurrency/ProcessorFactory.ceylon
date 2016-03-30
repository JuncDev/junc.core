import java.lang {
	Runnable
}


"factory to create new processors"
by( "Lis" )
shared interface ProcessorFactory
{
	"returns new processor"
	shared formal Processor createProcessor();
	
	"`true` if all running threads have high load level and no any thread can be added and `false` otherwise"
	shared formal Boolean overloaded;
	
	"execute [[exec]] - a long time function within some thread pool and using queue if all threads from th pool are busy"
	shared formal void executeBlocked( Runnable exec );
}
