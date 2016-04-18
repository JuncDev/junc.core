import herd.junc.api {
	Registration
}

import java.util.concurrent.atomic {
	AtomicLong,
	AtomicBoolean
}
import java.util.concurrent.locks {
	ReentrantLock
}


"Organizing thread safe two way list, which uses state items [[ListItem]].  
 The list can be locked which means that new items are added but marked as adding - not active
 and removed items are marked as dismissed but not actualy removed from list.
 The dismissed items will be actualy removed and adding items will be marked as active when list will be unlocked.   
 This leads to list stability when adding / removing items when iterating.
 When iterating the list items not active may be skipped.
 "
see( `class ListItem` )
by( "Lis" )
shared class TwoWayList<List>()
	given List satisfies ListItem<List>
{
	
	"list head item"
	variable List? headItem = null;
	"list tail item"
	variable List? tailItem = null;
	
	
	"list locking / unlocking value"
	AtomicLong lockCount = AtomicLong();
	
	"`true` if some items have been dismissed and to be removed from the list and `false` otherwise"
	AtomicBoolean containsDismissed = AtomicBoolean( false ); 
	
	"`true` if some items have been adding and to be activated and `false` otherwise"
	AtomicBoolean containsAdding = AtomicBoolean( false ); 
	
	"list modification lock"
	ReentrantLock listLock = ReentrantLock(); 
	
	
	"list head"
	shared List? head => headItem;
	
	"list tail"
	shared List? tail => tailItem;
	
	AtomicLong listSize = AtomicLong( 0 );
	
	"number of items in the list"
	shared Integer size => listSize.get();
	
	"`true` if list is empty and `false` otherwise"
	shared Boolean empty => size == 0;
	
	
	"Removes item from the list - doesn't matter lockedlist or not and item dismissed or not.  
	 Thread unsafe - use listLock.lock before call!"
	void doRemoveItem( ListItem<List> item ) {
		if ( item.state == ListItemState.stateDismissed ) {
			// remove from list
			if ( exists next = item.next ) {
				if ( exists prev = item.previous ) { prev.next = next; }
				else { headItem = next; }
				next.previous = item.previous;
			}
			else {
				if ( exists prev = item.previous ) {
					tailItem = prev;
					prev.next = null;
				}
				else {
					headItem = null;
					tailItem = null;
				}
			}
			// set item list data to avoid subsequent removing
			item.state = ListItemState.stateAlreadyRemoved;
			item.previous = null;
			item.next = null;
		}
	}
	
	"Updates the list - activating added and removing dismissed."
	void updateList() {
		if ( lockCount.compareAndSet( 0, 1 ) ) {
			listLock.lock();
			
			// remove dissmissed
			if ( containsDismissed.compareAndSet( true, false ) ) {
				variable List? list = headItem;
				while ( exists l = list ) {
					if ( l.state == ListItemState.stateDismissed ) {
						variable List? nextLife = l.next;
						while ( exists n = nextLife, n.state == ListItemState.stateDismissed ) {
							nextLife = n.next;
							n.state = ListItemState.stateAlreadyRemoved;
						}
						if ( exists n = nextLife ) {
							if ( exists prev = l.previous ) {
								prev.next = n;
								n.previous = prev;
							}
							else {
								headItem = n;
							}
							list = n.next;
						}
						else {
							if ( exists prev = l.previous ) {
								prev.next = null;
								tailItem = prev;
							}
							else {
								headItem = null;
								tailItem = null;
							}
							list = null;
						}
					}
					else {
						list = l.next;
					}
				}
			}
			
			// activate adding
			if ( containsAdding.compareAndSet( true, false ) ) {
				variable List? list = headItem;
				while ( exists l = list ) {
					list = l.next;
					if ( l.state == ListItemState.stateAdding ) {
						l.state = ListItemState.stateActive;
						listSize.incrementAndGet();
					}
				}
			}
			
			lockCount.decrementAndGet();
			listLock.unlock();
		}
	}

	"Returns registration for the item."
	Registration itemRegistration( List item ) {
		return object satisfies Registration {
			shared actual void cancel() => removeItem( item );
		};
	}
	
		
	"Locks the list from updation - activating added or removing dismissed items.  
	 Lock and unlock don't prevent ot add and remove items!
	 When locked newly added items marked by adding and removed items marked as dismissed but not actualy removed from the list.
	 Both adding and dismissed items may not be processed by subsequent owners, see [[ListItem.state]]."
	see( `function unlock` )
	shared void lock() => lockCount.incrementAndGet();
	
	"Unlock the list - updation is allowed if locking count equals to zero."
	see( `function lock` )
	shared void unlock() {
		if ( lockCount.decrementAndGet() == 0 ) { updateList(); }
	}
	
	"Removes all items."
	shared void clear() {
		listSize.set( 0 );
		if ( lockCount.get() == 0 ) {
			// remove all items if not locked
			listLock.lock();
			variable List? next = head;
			while( exists n = next ) {
				next = n.next;
				n.state = ListItemState.stateAlreadyRemoved;
				n.registration.reference = emptyRegistration;
				n.next = null;
				n.previous = null;
			}
			headItem = null;
			tailItem = null;
			listLock.unlock();
			containsDismissed.set( false );
			containsAdding.set( false );
		}
		else {
			// if locked - set dismissed for each item - their will be removed at unlocking
			variable List? next = head;
			while( exists n = next ) {
				next = n.next;
				n.state = ListItemState.stateDismissed;
				n.registration.reference = emptyRegistration;
			}
			containsDismissed.set( true );
			containsAdding.set( false );
		}
	}
	
	"Removes item from list or set dismissed if list locked."
	shared default void removeItem( List item ) {
		item.state = ListItemState.stateDismissed;
		item.registration.reference = emptyRegistration;
		listSize.decrementAndGet();
		// remove if not locked
		if ( lockCount.get() == 0 ) {
			listLock.lock();
			doRemoveItem( item );
			listLock.unlock();
		}
		else {
			containsDismissed.set( true );
		}
	}
	
	"Adds item last to the list. Returns registration to remove, activate or deactivate added item."
	shared Registration addToList( List item ) {
		listLock.lock();
		// add to list
		if ( exists t = tailItem ) {
			t.next = item;
			item.previous = t;
			item.next = null;
			tailItem = item;
		}
		else {
			headItem = item;
			tailItem = item;
			item.previous = null;
			item.next = null;
		}
		// activate if not locked
		if ( lockCount.get() == 0 ) {
			item.state = ListItemState.stateActive;
			listSize.incrementAndGet();
		}
		else {
			item.state = ListItemState.stateAdding;
			containsAdding.set( true );
		}
		
		listLock.unlock();
		item.registration.reference = itemRegistration( item );
		return item.registration.immutable;
	}
	
	
	"Next active item from item, including item or `null` if no.  
	 Doesn't lock the list - use [[lock]] before and [[unlock]] after.  
	 P.S. [[unlock]] do list update if no more locking. "
	shared List? nextActive( List? item ) {
		variable List? next = item;
		while ( exists n = next ) {
			next = n.next;
			if ( n.state == ListItemState.stateActive ) { return n; }
		}
		return null;
	}
	
	"Calls [[process]] for each active item."
	shared void forEachActive( "Function to be called for each active item." Anything(List) process ) {
		lock();
		try {
			variable List? next = head;
			while ( exists n = nextActive( next ) ) {
				next = n.next;
				process( n );
			}
		}
		finally { unlock(); }
	}
	
	"calls [[process]] for each active item"
	shared void forEachActiveMap<Mapped> (
		"function called to map, if returns `null` item is skipped" Mapped?(List) map,
		"function to be called for each mapped nonnull item" Anything(Mapped) process
	)
			given Mapped satisfies Object
	{
		lock();
		try {
			variable List? next = head;
			while ( exists n = nextActive( next ) ) {
				next = n.next;
				if ( exists m = map( n ) ) { process( m ); }
			}
		}
		finally { unlock(); }
	}	
}
