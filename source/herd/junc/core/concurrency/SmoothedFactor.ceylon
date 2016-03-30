
by( "Lis" )
class SmoothedFactor (
	"number of samples to calculate load factor" Integer sampleCapacity
) {
	"last calculated mean value"
	variable Float lastMean = 0.0;
	
	"smoothing factor"
	Float alpha = if ( sampleCapacity > 1 ) then 2.0 / ( sampleCapacity + 1 ) else 0.9;
	Float invertAlpha = 1 - alpha;
	
	"moving average"
	shared Float mean => lastMean;
	
	"reset to zero"
	shared void reset() { lastMean = 0.0; }
	
	"add new sample"
	shared void addSample( Float sample ) {
		lastMean = alpha * sample + invertAlpha * lastMean;
	}
	
	"repeat sample `sample` adding `n` times"
	shared void addTimes( Float sample, variable Integer n ) {
		if ( n < sampleCapacity ) {
			while ( n-- > 0 ) { addSample( sample ); }
		}
		else { lastMean = sample; }
	}
	
}
