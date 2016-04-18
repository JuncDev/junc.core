import herd.junc.api.monitor {

	AverageMetric,
	CounterMetric,
	GaugeMetric,
	MeterMetric
}

"A set of metrics."
by( "Lis" )
shared class MetricSet
(
	"Gauge metric list."
	shared {GaugeMetric<Anything>*} gauges,
	"Counter metric list."
	shared {CounterMetric*} counters,
	"Meter metric list."
	shared {MeterMetric*} meters,
	"Average metric list."
	shared {AverageMetric*} averages
) {}


"A something capable to write metrics."
see( `function Railway.addMetricWriter` )
by( "Lis" )
shared interface MetricWriter
{
	"Writes a metric set."
	shared formal void writeMetric( "Metric set to be written." MetricSet metrics );
}
