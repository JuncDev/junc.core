import herd.junc.api {
	Promise,
	Context,
	LoadLevel,
	Timer,
	Emitter,
	TimeRow,
	Publisher,
	TimeEvent
}


"processor is closable context"
by( "Lis" )
shared interface Processor satisfies Context
{
	
	"creates timer"
	shared formal Timer createTimer (
		"emitting with timer fires" Emitter<TimeEvent> onTime,
		"publishing to [[onTime]]" Publisher<TimeEvent> publisher,
		"strategy to fires" TimeRow times
	);
	
	"closes this processor.  
	 Returns promise resolved with this when closed or rejected if some errors occured"
	shared formal Promise<Processor> close();
	
	"`true` if processor is running and `false` if stopped"
	shared formal Boolean running;

	"current load level"
	shared formal LoadLevel loadLevel;
}