baremodule TaskDAGRecorders

export @sync, Threads

macro sync end
macro spawn end

function dag end
function sample end

module Internal

import ..TaskDAGRecorders: @sync, @spawn
using ..TaskDAGRecorders: TaskDAGRecorders

include("utils.jl")
include("recording.jl")
include("dag.jl")

end  # module Internal

"""
    TaskDAGRecorders.NTHREADS::Ref{Int}

The number of threads that `TaskDAGRecorders.Threads` pretends to have.
"""
const NTHREADS = Core.Ref(8)

nthreads() = NTHREADS[]

baremodule Threads
using ..TaskDAGRecorders: @sync, @spawn, nthreads
end  # baremodule Threads

end  # baremodule TaskDAGRecorders
