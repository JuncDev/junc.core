import herd.junc.api {
	Promise,
	Resolver
}


"can be proceeded or rejected"
by( "Lis" )
abstract class Executable() {
	shared formal void proceed();
	shared formal void reject( Throwable err );
	
	shared variable Executable? next = null;
}


by( "Lis" )
class VoidExecutable (
	Anything() run,
	Anything(Throwable)? notifyError = null	
)
		extends Executable()
{
	
	shared actual void proceed() {
		try {
			run();
		}
		catch ( Throwable err ) {
			if ( exists notifier = notifyError ) { notifier( err ); }
		}
	}
	
	shared actual void reject( Throwable err ) {
		if ( exists notifier = notifyError ) { notifier( err ); }
	}
}


"execute function with argument"
by( "Lis" )
class ArgumentedExecutable<Argument> (
	"function which will be run on the context when context is free"
	Anything(Argument) run,
	"function arguments"
	Argument arg,
	"notify if error occured during run"
	Anything( Throwable )? notifyError = null
)
		extends Executable()
{
	shared actual void proceed() {
		try { run( arg ); }
		catch ( Throwable err ) {
			if ( exists notifier = notifyError ) { notifier( err ); }
		}
	}
	shared actual void reject( Throwable err ) {
		if ( exists notifier = notifyError ) { notifier( err ); }
	}
}

"execute function with argument and returns result"
by( "Lis" )
class ResultExecutable<out Result, in Argument> (
	"function which will be run on the context when context is free"
	Result(Argument) run,
	"function argument"
	Argument arg,
	"resolving results"
	Resolver<Result> resolver
) 
		extends Executable()
{
	shared actual void proceed() {
		try { resolver.resolve( run( arg ) ); }
		catch ( Throwable err ) { resolver.reject( err ); }
	}
	shared actual void reject( Throwable err ) { resolver.reject( err ); }
}

"execute function with argument and returns promise"
by( "Lis" )
class PromiseExecutable<Result, Argument> (
	"function which will be run on the context when context is free"
	Promise<Result>(Argument) run,
	"function argument"
	Argument arg,
	"resolving results"
	Resolver<Result> resolver
) 
		extends Executable()
{
	shared actual void proceed() {
		try { resolver.defer( run( arg ) ); }
		catch ( Throwable err ) { resolver.reject( err ); }
	}
	shared actual void reject( Throwable err ) { resolver.reject( err ); }
}
