
While previous sections talked about running the testsuites for a
module and the packages therein, this has no meaning if the module in
question has no testsuites at all.

[para] This section gives a very basic overview on possible
methodologies for writing tests and testsuites.

[para] First there are "drudgery" tests. Written to check absolutely
basic assumptions which should never fail.

[para] For example for a command FOO taking two arguments, three tests
calling it with zero, one, and three arguments. The basic checks that
the command fails if it has not enough arguments, or too many.

[para] After that come the tests checking things based on our
knowledge of the command, about its properties and assumptions. Some
examples based on the graph operations added during Google's Summer of
Code 2009 are:

[list_begin itemized]

[item]	The BellmanFord command in struct::graph::ops takes a
	[arg startnode] as argument, and this node should be a node of
	the graph. This equals one test case checking the behavior when the
	specified node is not a node of the graph.

[para]  This often gives rise to code in the implementation which
	explicitly checks the assumption and throws an understandable error,
	instead of letting the algorithm fail later in some weird
	non-deterministic way.

[para]  It is not always possible to do such checks. The graph argument
	for example is just a command in itself, and while we expect
	it to exhibit a certain interface, i.e. a set of sub-commands
	aka methods, we cannot check that it has them, except by
	actually trying to use them. That is done by the algorithm
	anyway, so an explicit check is just overhead we can get by
	without.

[item]  IIRC one of the distinguishing characteristic of either
	BellmanFord and/or Johnson is that they are able to handle
	negative weights. Whereas Dijkstra requires positive weights.

[para]	This induces (at least) three testcases ... Graph with all
	positive weights, all negative, and a mix of positive and
	negative weights.

	Thinking further does the algorithm handle the weight
	[const 0] as well ? Another test case, or several, if we mix
	zero with positive and negative weights.

[item]	The two algorithms we are currently thinking about are about
	distances between nodes, and distance can be 'Inf'inity,
	i.e. nodes may not be connected. This means that good test
	cases are

	[list_begin enumerated]
	[enum]	Strongly connected graph
	[enum]	Connected graph
	[enum]	Disconnected graph.
	[list_end]

	[para] At the extremes of strongly connected and disconnected
	we have the fully connected graphs and graphs without edges,
	only nodes, i.e. completely disconnected.

[item]	IIRC both of the algorithms take weighted arcs, and fill in a
	default if arcs are left unweighted in the input graph.

	[para] This also induces three test cases:

	[list_begin enumerated]
	[enum]	Graph will all arcs with explicit weights.
	[enum]	Graph without weights at all.
	[enum]	Graph with mixture of weighted and unweighted graphs.
	[list_end]
[list_end]

[para] What was described above via examples is called
[term black-box] testing. Test cases are designed and written based on
the developer's knowledge of the properties of the algorithm and its
inputs, without referencing a particular implementation.

[para] Going further, a complement to [term black-box] testing is
[term white-box]. For this we know the implementation of the
algorithm, we look at it and design our tests cases so that they force
the code through all possible paths in the implementation. Wherever a
decision is made we have a test case forcing a specific direction of
the decision, for all possible combinations and directions. It is easy
to get a combinatorial explosion in the number of needed test-cases.

[para] In practice I often hope that the black-box tests I have made
are enough to cover all the paths, obviating the need for white-box
tests.

[para] The above should be enough to make it clear that writing tests
for an algorithm takes at least as much time as coding the algorithm,
and often more time. Much more time.

See for example also [uri http://sqlite.org/testing.html], a writeup
on how the Sqlite database engine is tested. Another article of
interest might be [uri https://www.researchgate.net/publication/298896236].
While geared to a particular numerical algorithm it still shows that
even a simple-looking algorithm can lead to an incredible number of
test cases.

[para] An interesting connection is to documentation. In one
direction, the properties checked with black-box testing are exactly
the properties which should be documented in the algorithm's man
page. And conversely, the documentation of the properties of an
algorithm makes a good reference to base the black-box tests on.

[para] In practice test cases and documentation often get written
together, cross-influencing each other. And the actual writing of test
cases is a mix of black and white box, possibly influencing the
implementation while writing the tests. Like writing a test for a
condition like [term {startnode not in input graph}] serving as
reminder to put a check for this condition into the code.
