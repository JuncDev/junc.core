import ceylon.collection {
	HashMap
}

import herd.junc.api {
	Registration,
	Timer,
	JuncTrack,
	PeriodicTimeRow,
	TimeEvent
}
import herd.junc.api.monitor {
	Counter,
	CounterMetric,
	Gauge,
	GaugeMetric,
	MeterMetric,
	Monitor,
	Priority,
	Meter,
	AverageMetric,
	Average
}
import herd.junc.core.concurrency {
	ContextReference,
	currentContext
}
import herd.junc.core.utils {
	DualList,
	ListBody,
	emptyRegistration
}
import herd.junc.core.wire {
	completedTimer
}

import java.util.concurrent.atomic {
	AtomicBoolean
}
import java.util.concurrent.locks {
	ReentrantLock
}
import herd.junc.core {

	LogWriter,
	MetricWriter,
	MetricSet
}


"Provides monitoring of metrics."
by( "Lis" )
shared class Monitoring (
	"Metric writing period." Integer metricWriteMilliseconds,
	"Log priority." shared Priority priority = Priority.info
)
	satisfies Monitor
{
	
	"`True` if monitoring is doing and `false` if restricted."
	Boolean monitoringAvailable = metricWriteMilliseconds > 100;
	
	"Context monitor to work on."
	ContextReference contextRef = ContextReference( currentContext );
	variable Timer timer = completedTimer;
	
	
	"Log writes."
	DualList<LogWriter> logWriters = DualList<LogWriter>();
	
	class LogMessage( String identifier, Priority priority, String message, Throwable? throwable ) {
		void sendToWriter( ListBody<LogWriter> writer ) {
			writer.body.writeLogMessage( identifier, priority, message, throwable );
		}
		shared void writeLog() => logWriters.forEachActive( sendToWriter );
	}	
	
	ReentrantLock raceLock = ReentrantLock();
	
	"gauges"
	HashMap<String, GaugeStore<Anything, Nothing>> gauges = HashMap<String, GaugeStore<Anything, Nothing>>();
	variable GaugeMetric<Anything>[] gaugesImmut = [];
	AtomicBoolean gaugesModified = AtomicBoolean( false );
	
	"counters"
	HashMap<String, Countered> counters = HashMap<String, Countered>();
	variable CounterMetric[] countersImmut = []; 
	AtomicBoolean countersModified = AtomicBoolean( false );
	
	"meters"
	HashMap<String, Metered> meters = HashMap<String, Metered>();
	variable MeterMetric[] metersImmut = [];
	AtomicBoolean metersModified = AtomicBoolean( false );
	
	"averaged"
	HashMap<String, Averaged> averages = HashMap<String, Averaged>();
	variable AverageMetric[] averagesImmut = [];
	AtomicBoolean averagesModified = AtomicBoolean( false );
	
	
	"metric writes"
	DualList<MetricWriter> metricWriters = DualList<MetricWriter>(); 
	
	
	class MetricSetProcessor() extends MetricSet( gaugesImmut, countersImmut, metersImmut, averagesImmut ) {
		shared void process( ListBody<MetricWriter> writer ) {
			writer.body.writeMetric( this );
		}
	}
	
	
	"Performs log and metric writing operations on specified context."
	shared void useTrack( JuncTrack track ) {
		timer.stop();
		contextRef.reference = track.context;
		if ( monitoringAvailable ) {
			timer = track.createTimer( PeriodicTimeRow( metricWriteMilliseconds ) );
			timer.onData( writeMetricsByTime );
			timer.start();
		}
	}
	
	
	"Adds log writer.  Returns registration to remove added log writer."
	shared Registration addLogWriter( LogWriter logWriter ) => logWriters.addItem( logWriter );
	
	shared actual Boolean enabled( Priority priority ) => this.priority <= priority;
	
	shared actual void log( String identifier, Priority priority, String message, Throwable? throwable ) {
		if ( enabled ( priority ) ) {
			contextRef.reference.execute( LogMessage( identifier, priority, message, throwable ).writeLog );
		}
	}
	
	
	"Adds metric writer.  Returns registration to remove added metric writer."
	shared Registration addMetricWriter( MetricWriter metricWriter ) {
		if ( monitoringAvailable ) { return metricWriters.addItem( metricWriter ); }
		else { return emptyRegistration; }
	}

	"Forces metrics writing.  By default may not be called since it is called by timer."
	shared void writeMetrics() {
		if ( monitoringAvailable ) { contextRef.reference.execute( doWriteMetrics ); }
	}
	
	
	"Process metrics writing by timer."
	void writeMetricsByTime( TimeEvent timeEvent ) => doWriteMetrics();
	
	"Do writing itself."
	void doWriteMetrics() {
		raceLock.lock();
		try {
			// if gauges map has been modified - add them to immutable list
			if ( gaugesModified.compareAndSet( true, false ) ) {
				gaugesImmut = gauges.items.sequence();
			}
			
			// if counters map has been modified - add them to immutable list
			if ( countersModified.compareAndSet( true, false ) ) {
				countersImmut = counters.items.sequence();
			}
			
			// if metric map has been modified - add them to immutable list
			// calculate meters
			Integer milliseconds = system.milliseconds;
			for ( m in meters.items ) { m.calculate( milliseconds ); }
			// make meters immutable map
			if ( metersModified.compareAndSet( true, false ) ) {
				metersImmut = meters.items.sequence();
			}
			
			// if averages map has been modified - add them to immutable list
			if ( averagesModified.compareAndSet( true, false ) ) {
				averagesImmut = averages.items.sequence();
			}
		}
		finally { raceLock.unlock(); }
		
		// write metrics
		metricWriters.forEachActive( MetricSetProcessor().process );
	}
	
	
	shared actual Boolean containsGauge( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try { return gauges.defines( name ); }
			finally { raceLock.unlock(); }
		}
		else {
			return false;
		}
	}
	
	shared actual Gauge<T>? gauge<T>( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				if ( exists g = gauges.get( name ) ) {
					if ( is GaugeStore<T, T> g ) { return g.gauge; }
					else { return null; }
				}
				else {
					Gauged<T> g = Gauged<T>( name );
					gauges.put( name, g );
					gaugesModified.set( true );
					return g.gauge;
				}
			}
			finally { raceLock.unlock(); }
		}
		else {
			return EmptyGauge<T>();
		}
	}
	
	shared actual void removeGauge( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				gauges.remove( name );
				gaugesModified.set( true );
			}
			finally { raceLock.unlock(); }
		}
	}
	
	
	shared actual Boolean containsCounter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try { return counters.defines( name ); }
			finally { raceLock.unlock(); }
		}
		else {
			return false;
		}
	}

	shared actual Counter counter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				if ( exists c = counters.get( name ) ) { return c; }
				else {
					Countered c = Countered( name );
					counters.put( name, c );
					countersModified.set( true );
					return c;
				}
			}
			finally { raceLock.unlock(); }
		}
		else {
			return emptyCounter;
		}
	}
	
	shared actual void removeCounter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				counters.remove( name );
				countersModified.set( true );
			}
			finally { raceLock.unlock(); }
		}
	}
	
	
	shared actual Boolean containsMeter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try { return meters.defines( name ); }
			finally { raceLock.unlock(); }
		}
		else {
			return false;
		}
	}
	
	shared actual Meter meter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				if ( exists m = meters.get( name ) ) { return m; }
				else if ( metricWriteMilliseconds > 0 ) {
					Metered m = Metered( name, 2 * metricWriteMilliseconds );
					meters.put( name, m );
					metersModified.set( true );
					return m;
				}
				else { return emptyMeter; }
			}
			finally { raceLock.unlock(); }
		}
		else {
			return emptyMeter;
		}
	}
	
	shared actual void removeMeter( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				meters.remove( name );
				metersModified.set( true );
			}
			finally { raceLock.unlock(); }
		}
	}
	
	
	shared actual Boolean containsAverage( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try { return averages.defines( name ); }
			finally { raceLock.unlock(); }
		}
		else {
			return false;
		}
	}
	
	shared actual Average average( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				if ( exists a = averages.get( name ) ) { return a; }
				else {
					Averaged a = Averaged( name );
					averages.put( name, a );
					averagesModified.set( true );
					return a;
				}
			}
			finally { raceLock.unlock(); }
		}
		else {
			return emptyAverage;
		}
	}
	
	shared actual void removeAverage( String name ) {
		if ( monitoringAvailable ) {
			raceLock.lock();
			try {
				averages.remove( name );
				averagesModified.set( true );
			}
			finally { raceLock.unlock(); }
		}
	}
	
}
