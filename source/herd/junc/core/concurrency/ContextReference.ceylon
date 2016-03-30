import herd.junc.api {
	Promise,
	Context,
	Deferred
}
import herd.junc.core.utils {
	Reference
}


"conext reference - to replace context"
by( "Lis" )
shared class ContextReference( Context init )
	extends Reference<Context>( init )
{

	shared object context satisfies Context {
		shared actual void execute( Anything() run, Anything(Throwable)? notifyError ) => reference.execute( run, notifyError );
	
		shared actual void executeWithArgument<Argument> (
			Anything(Argument) run, Argument arg, Anything(Throwable)? notifyError
		) => reference.executeWithArgument<Argument>( run, arg, notifyError );
	
		shared actual Promise<Result> executeWithResults<Result, Argument> (
			Result(Argument) run, Argument arg
		) => reference.executeWithResults<Result, Argument>( run, arg );
		
		shared actual Promise<Result> executeWithPromise<Result, Argument> (
			Promise<Result>(Argument) run, Argument arg
		) => reference.executeWithPromise( run, arg );
	
		shared actual Promise<Value> deferredPromise<Value>(Promise<Value> val)
				=> reference.deferredPromise<Value>( val );
		
		shared actual Deferred<Value> newResolver<Value>()
				=> reference.newResolver<Value>();
		
		shared actual Promise<Nothing> rejectedPromise( Throwable err )
				=> reference.rejectedPromise( err );
		
		shared actual Promise<Value> resolvedPromise<Value>( Value val )
				=> reference.resolvedPromise<Value>( val );
		
	}
	
}
