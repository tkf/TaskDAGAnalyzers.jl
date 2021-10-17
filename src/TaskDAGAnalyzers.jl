baremodule TaskDAGAnalyzers

function dag end
function span end
function work end
function parallelism end
function summary end

module Internal

using ..TaskDAGAnalyzers: TaskDAGAnalyzers

using TaskDAGRecorders
using TaskDAGRecorders.Internal: AnyContext, SyncContext, TaskContext, TaskStat, _get!

import ShowGraphviz

include("dag.jl")
include("graphviz.jl")
include("summary.jl")

end  # module Internal

module Examples
include("examples.jl")
end  # module Examples

end  # baremodule TaskDAGAnalyzers
