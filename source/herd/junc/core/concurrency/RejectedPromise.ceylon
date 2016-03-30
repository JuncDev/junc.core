import herd.junc.api {
	Promise,
	Context
}


"promise already rejected with some [[reason]], so all operations will be rejected with this [[reason]]"
by( "Lis" )
class RejectedPromise (
	"rejecting reason" Throwable reason,
	"context the promise is rejected on" Context context
 )
		satisfies Promise<Nothing>
{
	
	shared actual Promise<Nothing> onComplete (
		Anything(Nothing) completeHandler,
		Anything(Throwable)? rejectHandler
	) {
		if ( exists r = rejectHandler ) { context.executeWithArgument( r, reason ); }
		return this;
	}
	
	shared actual Promise<Nothing> onError( Anything(Throwable) rejectHandler ) {
		context.executeWithArgument( rejectHandler, reason );
		return this;
	}
	
	shared actual Promise<Result> compose<Result>( Promise<Result>(Nothing) completeHandler, Context? retContext )
			=> if( exists r = retContext ) then r.rejectedPromise( reason ) else this;
	
	shared actual Promise<Result> map<Result>( Result mapping( Nothing val ), Context? retContext )
			=> if( exists r = retContext ) then r.rejectedPromise( reason ) else this;
	
	shared actual Promise<Result> and<Result, Other> (
		Promise<Other> other, Promise<Result> mapping( Nothing val, Other otherVal ), Context? retContext
	)
			=> if( exists r = retContext ) then r.rejectedPromise( reason ) else this;
	
	shared actual Promise<Nothing> contexting( Context other ) => other.rejectedPromise( reason );
}
