import java.lang {
	Runnable
}


"Factory to create new processors."
by( "Lis" )
shared interface ProcessorFactory
{
	"Creates new processor."
	shared formal void createProcessor( void onCreated(Processor processor) );
	
	"`True` if more threads can be added and `false` otherwise."
	shared formal Boolean extensible;
	
	"Execute [[exec]] - a long time function within some thread pool and using queue if all threads from th pool are busy."
	shared formal void executeBlocked( Runnable exec );
}
