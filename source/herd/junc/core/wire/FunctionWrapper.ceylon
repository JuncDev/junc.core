
"Just wraps a function in order to increase `is` operator performance."
by( "Lis" )
class FunctionWrapper<in Arg>(
	shared Anything(Arg) func
) {}
