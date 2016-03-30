import ceylon.collection {
	TreeSet,
	naturalOrderTreeSet
}

import herd.junc.api.monitor {
	Monitor,
	Counter,
	Average,
	Priority,
	Meter,
	Gauge
}


"Monitor which refs to another one and removes all monitored values when closed."
by( "Lis" )
shared class MonitorRef( Monitor monitor ) satisfies Monitor
{
	TreeSet<String> averages = naturalOrderTreeSet<String>( {} );
	TreeSet<String> counters = naturalOrderTreeSet<String>( {} );
	TreeSet<String> gauges = naturalOrderTreeSet<String>( {} );
	TreeSet<String> meters = naturalOrderTreeSet<String>( {} );
	
	
	"Removes all monitored value."
	shared void clear() {
		for ( item in averages ) { monitor.removeAverage( item ); }
		averages.clear();
		for ( item in counters ) { monitor.removeCounter( item ); }
		counters.clear();
		for ( item in gauges ) { monitor.removeGauge( item ); }
		gauges.clear();
		for ( item in meters ) { monitor.removeMeter( item ); }
		meters.clear();
	}
	
	
	shared actual void log( String identifier, Priority priority, String message, Throwable? throwable )
			=> monitor.log( identifier, priority, message, throwable );
	
	shared actual Boolean enabled( Priority priority ) => monitor.enabled( priority );
	
	
	shared actual Boolean containsAverage( String name ) => monitor.containsAverage( name );
	
	shared actual Average average( String name ) {
		if ( !monitor.containsAverage( name ) ) { averages.add( name ); }
		return monitor.average( name );
	}
	
	shared actual void removeAverage( String name ) {
		averages.remove( name );
		monitor.removeAverage( name );
	}
	
	
	shared actual Boolean containsCounter( String name ) => monitor.containsCounter( name );
	
	shared actual Counter counter( String name ) {
		if ( !monitor.containsCounter( name ) ) { counters.add( name ); }
		return monitor.counter( name );
	}
	
	shared actual void removeCounter( String name ) {
		counters.remove( name );
		monitor.removeCounter( name );
	}
	
	
	shared actual Boolean containsGauge( String name ) => monitor.containsGauge( name );
	
	shared actual Gauge<T>? gauge<T>( String name ) {
		if ( !monitor.containsGauge( name ) ) { gauges.add( name ); }
		return monitor.gauge<T>( name );
	}
	
	shared actual void removeGauge( String name ) {
		gauges.remove( name );
		monitor.removeGauge( name );
	}

	
	shared actual Boolean containsMeter( String name ) => monitor.containsMeter( name );

	shared actual Meter meter( String name ) {
		if ( !monitor.containsMeter( name ) ) { meters.add( name ); }
		return monitor.meter( name );
	}
	
	shared actual void removeMeter( String name ) {
		meters.remove( name );
		monitor.removeMeter( name );
	}
	
}
