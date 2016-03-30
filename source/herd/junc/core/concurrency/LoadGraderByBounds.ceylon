import herd.junc.api {

	LoadLevel
}


"simple load grader changed grade between bounds"
by( "Lis" )
shared class LoadGraderByBounds (
	"bound at which low load level becames middle" Float lowMiddleBound,
	"bound at which middle load level becames low" Float middleLowBound,
	"bound at which middle load level becames high" Float middleHighBound,
	"bound at which high load level becames middle" Float highMiddleBound
)
		satisfies LoadGrader
{
	
	shared actual LoadLevel grade( Float factor, LoadLevel current ) {
		switch ( current )
		case ( LoadLevel.lowLoadLevel ) {
			if ( factor < lowMiddleBound ) { return LoadLevel.lowLoadLevel; }
			else if ( factor < middleHighBound ) { return LoadLevel.middleLoadLevel; }
			else { return LoadLevel.highLoadLevel; }
		}
		case ( LoadLevel.middleLoadLevel ) {
			if ( factor < middleLowBound ) { return LoadLevel.lowLoadLevel; }
			else if ( factor < middleHighBound ) { return LoadLevel.middleLoadLevel; }
			else { return LoadLevel.highLoadLevel; }
		}
		case ( LoadLevel.highLoadLevel ) {
			if ( factor < middleLowBound ) { return LoadLevel.lowLoadLevel; }
			else if ( factor < highMiddleBound ) { return LoadLevel.middleLoadLevel; }
			else { return LoadLevel.highLoadLevel; }
		}
	}
}

