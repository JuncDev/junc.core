import java.util.concurrent.atomic {

	AtomicReference
}


"atomic reference to object"
by( "Lis" )
shared class Reference<Item>( Item initial )
{
	AtomicReference<Item> ref = AtomicReference<Item>( initial ); 
	
	shared Item reference => ref.get();
	assign reference => ref.set( reference );
	
	shared Item getAndSet( Item item ) => ref.getAndSet( item );
	shared Boolean compareAndGet( Item toCompare, Item toSet ) => ref.compareAndSet( toCompare, toSet );
}