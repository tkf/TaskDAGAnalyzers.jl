baremodule TaskDAGRecorders

export @sync, Threads

macro sync end
macro spawn end

function sample end

const NTHREADS = Core.Ref(8)
nthreads() = NTHREADS[]

"""
    TaskDAGRecorders.Internal

This module contains the internal details.
"""
module Internal

import ..TaskDAGRecorders: @sync, @spawn
using ..TaskDAGRecorders: TaskDAGRecorders

include("utils.jl")
include("recording.jl")

end  # module Internal

"""
    TaskDAGRecorders.Threads

A shim of `Base.Threads` that provides a subset of `Threads` for instrumenting
`@spawn` and `@sync`.
"""
baremodule Threads
using ..TaskDAGRecorders: @sync, @spawn, nthreads
end  # baremodule Threads

"""
    TaskDAGRecorders.NTHREADS::Ref{Int}

The number of threads that `TaskDAGRecorders.Threads` pretends to have.
"""
NTHREADS

end  # baremodule TaskDAGRecorders
