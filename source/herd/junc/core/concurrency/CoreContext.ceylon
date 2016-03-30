import herd.junc.api {
	
	Promise,
	Deferred,
	Context
}


"provides resolved, resolvePromise and rejectedPromise implementation"
by( "Lis" )
shared interface CoreContext satisfies Context
{
	shared actual default Deferred<Value> newResolver<Value>()
			=> DeferredValue<Value>( this ).resolver;
	
	shared actual default Promise<Value> resolvedPromise<Value>( Value val )
			=> ResolvedPromise<Value>( val, this );
	
	shared actual default Promise<Value> deferredPromise<Value>( Promise<Value> val )
	{
		DeferredValue<Value> def = DeferredValue<Value>( this );
		def.resolver.defer( val );
		return def.promise;
	}
	
	shared actual default Promise<Nothing> rejectedPromise( Throwable err )
			=> RejectedPromise( err, this );	
}
