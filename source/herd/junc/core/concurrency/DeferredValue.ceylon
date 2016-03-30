import herd.junc.api {
	Promise,
	Context,
	Deferred
}
import herd.junc.core.utils {
	ListBody,
	DualList
}

import java.util.concurrent.atomic {
	AtomicReference,
	AtomicBoolean
}


"deferred - promise container and resolver"
by( "Lis" )
class DeferredValue<Value>( "context promised resolved or rejected on" Context context )
	//given Value satisfies Object
{

	"promise state - one of promise, resolved or rejected"
	interface State
	{
		shared formal void resolve( Value val );
		shared formal void defer( Promise<Value> val );
		shared formal void reject( Throwable reason );
		
		shared formal void onComplete (
			Anything(Value) completeHandler,
			Anything( Throwable )? rejectHandler = null
		);
		shared formal void onError( Anything( Throwable ) rejectHandler );
		shared formal Promise<Result> compose<Result> (
			Promise<Result>(Value) completeHandler, Context? retContext
		);// given Result satisfies Object;
		shared formal Promise<Result> and<Result, Other> (
			Promise<Other> other, Promise<Result> mapping(Value val, Other otherVal), Context? retContext
		);// given Result satisfies Object  given Other satisfies Object;
		shared formal Promise<Result> map<Result> (
			Result mapping( Value val ), Context? retContext
		);// given Result satisfies Object;
		shared formal Promise<Value>? contexting( Context other );
	}
	
	
	"current promise state - null specified here, but late within initialization [[PromiseState]] is set"
	AtomicReference<State> current = AtomicReference<State>( null );
	
	
	"promise has been resolved"
	class ResolvedOrRejectedState( Promise<Value> promise ) satisfies State {
		
		shared actual void onComplete (
			Anything( Value ) completeHandler,
			Anything( Throwable )? rejectHandler
		) => promise.onComplete( completeHandler, rejectHandler );
		
		shared actual void onError( Anything( Throwable ) rejectHandler )
				=> promise.onError( rejectHandler );
		
		shared actual Promise<Result> compose<Result>( Promise<Result>(Value) completeHandler, Context? retContext )
				=> promise.compose<Result>( completeHandler, retContext );
		
		shared actual Promise<Result> and<Result, Other> (
			Promise<Other> other, Promise<Result> mapping(Value val, Other otherVal), Context? retContext
		)
				=> promise.and( other, mapping, retContext );
		
		shared actual Promise<Result> map<Result>( Result mapping( Value val ), Context? retContext )
				=> promise.map( mapping, retContext );
		
		shared actual Promise<Value>? contexting( Context other ) => promise.contexting( other );
		
		shared actual void reject( Throwable reason ) {
			// do nothing - since already resolved
		}
		
		shared actual void resolve( Value val ) {
			// do nothing - since already resolved
		}
		
		shared actual void defer( Promise<Value> val ) {
			// do nothing - since already resolved
		}
		
	}
	
	"waiting to resolve or reject"
	class PromiseState() satisfies State {
		
		"handlers list"
		DualList<Anything(Value)> handlers = DualList<Anything(Value)>();
		DualList<Anything(Throwable)> errorHandlers = DualList<Anything(Throwable)>();
		
		
		"`true` if in promised state i.e. not resolved or rejected and `false` otherwise"
		AtomicBoolean promised = AtomicBoolean( true );
		
		
		"rejecting all handlers, to be called on [[context]]"
		void doReject( Throwable reason ) {
			errorHandlers.lock();
			variable ListBody<Anything(Throwable)>? handler = errorHandlers.head;
			while( exists h = errorHandlers.nextActive( handler ) ) {
				handler = h.next;
				h.body( reason );
			}
			errorHandlers.unlock();
			release();
		}
		
		"resolving all handlers, to be called on [[context]]"
		void doResolve( Value val ) {
			handlers.lock();
			variable ListBody<Anything(Value)>? handler = handlers.head;
			while( exists h = handlers.nextActive( handler ) ) {
				handler = h.next;
				h.body( val );
			}
			handlers.unlock();
			release();
		}
		
		
		void rejectDefer( Throwable reason ) {
			current.set( ResolvedOrRejectedState( context.rejectedPromise( reason ) ) );
			if ( !errorHandlers.empty ) { context.executeWithArgument( doReject, reason ); }
			else { release(); }
		}
		
		void resolveDefer( Value val ) {
			current.set( ResolvedOrRejectedState( context.resolvedPromise( val ) ) );
			if ( !handlers.empty ) { context.executeWithArgument( doResolve, val, doReject ); }
			else { release(); }
		}
		
		
		void release() {
			handlers.clear();
			errorHandlers.clear();
		}
		
		
		shared actual void onComplete (
			Anything(Value) completeHandler,
			Anything(Throwable)? rejectHandler
		) {
			handlers.addItem( completeHandler );
			if ( exists r = rejectHandler ) { errorHandlers.addItem( r ); }
		}
		
		shared actual void onError( Anything(Throwable) rejectHandler ) => errorHandlers.addItem( rejectHandler );
		
		
		shared actual Promise<Result> compose<Result>( Promise<Result>(Value) completeHandler, Context? retContext )
		{
			Context resolveContext = if ( exists r = retContext ) then r else context;
			Deferred<Result> def = resolveContext.newResolver<Result>();
			onComplete (
				(Value result) => def.defer( completeHandler( result ) ),
				(Throwable reason) => def.reject( reason )
			);
			return def.promise;
		}
		
		shared actual Promise<Result> and<Result, Other> (
			Promise<Other> other, Promise<Result> mapping(Value val, Other otherVal), Context? retContext
		) {
			return compose<Result> (
				( Value val ) {
					return other.compose<Result> (
						(Other otherVal) => context.executeWithPromise (
							(Other ov) => mapping( val, otherVal ), otherVal )
					);
				},
				retContext
			);
		}
		
		shared actual Promise<Result> map<Result>( Result mapping( Value val ), Context? retContext ) {
			Context resolveContext = if ( exists r = retContext ) then r else context;
			value res = resolveContext.newResolver<Result>();
			onComplete (
				(Value val) => res.resolve( mapping( val ) ),
				res.reject
			);
			return res.promise;
		}
		
		shared actual Promise<Value>? contexting( Context other ) => null;
		
		
		shared actual void reject( Throwable reason ) {
			if ( promised.compareAndSet( true, false ) ) { rejectDefer( reason ); }
		}
		
		shared actual void resolve( Value val ) {
			if ( promised.compareAndSet( true, false ) ) { resolveDefer( val ); }
		}
		
		shared actual void defer( Promise<Value> val ) {
			if ( promised.compareAndSet( true, false ) ) { val.onComplete( resolveDefer, rejectDefer ); }
		}
	}
	
	
	// set promise state as current at initializer
	current.compareAndSet( null, PromiseState() );
	
	
	"promise this deferred possess"
	shared object promise satisfies Promise<Value> {
		
		shared actual Promise<Value> onComplete (
			void completeHandler( Value val ),
			Anything( Throwable )? rejectHandler
		) {
			current.get().onComplete( completeHandler, rejectHandler );
			return this;
		}
		
		shared actual Promise<Value> onError( Anything( Throwable ) rejectHandler ) {
			current.get().onError( rejectHandler );
			return this;
		}
		
		shared actual Promise<Result> compose<Result>( Promise<Result>(Value) completeHandler, Context? retContext )
				=> current.get().compose<Result>( completeHandler, retContext );
		
		shared actual Promise<Result> and<Result, Other> (
			Promise<Other> other, Promise<Result> mapping( Value val, Other otherVal ), Context? retContext
		) => current.get().and( other, mapping, retContext );
		
		shared actual Promise<Result> map<Result>( Result mapping( Value val ), Context? retContext )
				=> current.get().map( mapping, retContext );
		
		shared actual Promise<Value> contexting( Context other ) =>
			if ( exists ret = current.get().contexting( other ) ) then ret
			else other.deferredPromise( this );
		
	}
	
	"resolver to resolve this deferred"
	shared object resolver satisfies Deferred<Value> {
		shared actual Promise<Value> promise => outer.promise;
		shared actual void reject( Throwable reason ) => current.get().reject( reason );
		shared actual void resolve( Value val ) => current.get().resolve( val );
		shared actual void defer( Promise<Value> other ) => current.get().defer( other );
	}
	
}
