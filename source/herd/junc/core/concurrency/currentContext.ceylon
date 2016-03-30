import herd.junc.api {
	Promise
}


"executes immediately on the current context"
by( "Lis" )
shared object currentContext satisfies CoreContext
{
	shared actual void execute( Anything() run, Anything( Throwable )? notifyError ) {
		try { run(); }
		catch ( Throwable err ) { if ( exists notifyError ) { notifyError( err ); } }
	}
	
	shared actual void executeWithArgument<Argument> (
		Anything(Argument) run, Argument arg, Anything(Throwable)? notifyError
	) {
		try { run( arg ); }
		catch ( Throwable err ) { if ( exists notifyError ) { notifyError( err ); } }
	}
	
	shared actual Promise<Result> executeWithResults<Result, Argument> (
		Result(Argument) run, Argument arg
	) {
		try { return resolvedPromise<Result>( run( arg ) ); }
		catch ( Throwable err ) { return rejectedPromise( err ); }
	}
	
	shared actual Promise<Result> executeWithPromise<Result, Argument> (
		Promise<Result>(Argument) run, Argument arg
	) {
		try { return deferredPromise<Result>( run( arg ) ); }
		catch ( Throwable err ) { return rejectedPromise( err ); }
	}
	
}
