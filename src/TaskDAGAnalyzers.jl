baremodule TaskDAGAnalyzers

module Internal

using ..TaskDAGAnalyzers: TaskDAGAnalyzers

using TaskDAGRecorders
using TaskDAGRecorders.Internal: DAG, SpawnNode, SyncNode, SequentialNode, DurationNS, _get!

import ShowGraphviz

include("graphviz.jl")

end  # module Internal

module Examples
include("examples.jl")
end  # module Examples

end  # baremodule TaskDAGAnalyzers
