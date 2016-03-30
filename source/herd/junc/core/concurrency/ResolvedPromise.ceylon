import herd.junc.api {
	Promise,
	Context
}


"promise already resolved with value or another promise.  
 If resolved with another promise all operations will be redirected to"
by( "Lis" )
class ResolvedPromise<Value> (
	"resolved value or promise" Value val,
	"context the promise is resolved or rejected on" Context context
)
		satisfies Promise<Value>
{
	
	shared actual Promise<Value> onComplete (
		Anything(Value) completeHandler,
		Anything(Throwable)? rejectHandler
	) {
		context.executeWithArgument( completeHandler, val, rejectHandler );
		return this;
	}
	
	shared actual Promise<Value> onError( Anything(Throwable) rejectHandler ) {
		return this;
	}
	
	
	shared actual Promise<Result> compose<Result>( Promise<Result>(Value) completeHandler, Context? retContext )
		=>	if ( exists r = retContext )
			then r.deferredPromise<Result>( context.executeWithPromise( completeHandler, val ) )
			else context.executeWithPromise( completeHandler, val );
	
	shared actual Promise<Result> and<Result, Other> (
		Promise<Other> other, Promise<Result> mapping(Value val, Other otherVal), Context? retContext
	)
		=>	if ( exists r = retContext )
			then other.compose<Result> (
					(Other otherVal) => context.executeWithPromise (
						(Other ov) => mapping( val, ov ), otherVal ),
						r
					)
			else other.compose<Result> (
					(Other otherVal) => context.executeWithPromise (
						(Other ov) => mapping( val, otherVal ), otherVal ),
						context
				);
	
	shared actual Promise<Result> map<Result>( Result mapping( Value val ), Context? retContext )
		=>	if ( exists r = retContext )
			then r.deferredPromise<Result>( context.executeWithResults( mapping, val ) )
			else context.executeWithResults( mapping, val );
	
	shared actual Promise<Value> contexting( Context other ) => other.resolvedPromise( val );
}
