TaskDAGAnalyzers.dag(ctx::SyncContext = get_sync_context(); kwargs...) =
    simplify!(DAG(ctx); kwargs...)

abstract type DAG{T} end

mutable struct SyncNode{T} <: DAG{T}
    continuation::Union{Nothing,DAG{T}}
end

mutable struct SpawnNode{T} <: DAG{T}
    data::T
    detach::DAG{T}
    continuation::DAG{T}
    sync::SyncNode{T}
end

mutable struct SequentialNode{T} <: DAG{T}
    data::T
    continuation::DAG{T}
end

function dummy_pre(stat::TaskStat)
    dummy = TaskStat()
    dummy.stop = stat.start
    return dummy
end

function dummy_post(stat::TaskStat)
    dummy = TaskStat()
    dummy.start = stat.stop
    return dummy
end

DAG{T}(f, ctx::SyncContext) where {T} = DAG{T}(f, ctx, nothing)

function DAG{T}(f, ctx::AnyContext, k) where {T}
    local sync::SyncNode{T}  # not used if ctx isa TaskContext
    if ctx isa SyncContext
        k = sync = SyncNode{T}(k)
    else
        ctx::TaskContext
        k::SyncNode{T}
    end
    stat = dummy_post(ctx.stat)
    for child in Iterators.reverse(ctx.children)
        child = child::AnyContext
        kc = SequentialNode{T}(f(child.stat, stat), k)  # continuation of child
        stat = child.stat
        if child isa TaskContext
            k = SpawnNode{T}(f(child.stat), DAG{T}(f, child, sync), kc, sync)
        else
            child::SyncContext
            k = DAG{T}(f, child, kc)
        end
    end
    return SequentialNode{T}(f(dummy_pre(ctx.stat), stat), k)
end

struct DurationNS
    value::Int
end

Base.Real(d::DurationNS) = d.value

duration(stat::TaskStat) = DurationNS(stat.stop - stat.start)
duration(pre::TaskStat, post::TaskStat) = DurationNS(post.start - pre.stop)

DAG(ctx::SyncContext) = DAG{DurationNS}(duration, ctx)

# TODO: generalize to arbitrary "weight"
function TaskDAGAnalyzers.work(dag::DAG{DurationNS})
    w = 0
    while true
        if dag === nothing
            break
        elseif dag isa SpawnNode
            w += TaskDAGAnalyzers.work(dag.detach).value
        elseif dag isa SequentialNode
            w += dag.data.value
        else
            dag::SyncNode
        end
        dag = dag.continuation
    end
    return DurationNS(w)
end

function TaskDAGAnalyzers.span(dag::DAG{DurationNS})
    parent = 0
    maxchild = 0
    while true
        if dag === nothing
            break
        elseif dag isa SpawnNode
            maxchild = max(maxchild, TaskDAGAnalyzers.span(dag.detach).value)
        elseif dag isa SequentialNode
            parent += dag.data.value
        else
            dag::SyncNode
        end
        dag = dag.continuation
    end
    return DurationNS(max(parent, maxchild))
end

function simplify!(dag::DAG{DurationNS}; noisefloor::Real = 0.01)
    noisefloor == 0 && return dag
    0 ≤ noisefloor ≤ 1 || error("invalid `noisefloor`: ", noisefloor)
    noisefloor_ns = TaskDAGAnalyzers.span(dag).value * noisefloor

    simplified = IdDict{DAG{DurationNS},DAG{DurationNS}}()
    simp!(dag) = _get!(() -> _simp!(dag), simplified, dag)

    _simp!(dag::SequentialNode{DurationNS}) =
        if dag.data.value < noisefloor_ns
            simp!(dag.continuation)
        else
            # @show dag.data.value noisefloor_ns dag.data.value / noisefloor_ns
            SequentialNode{DurationNS}(dag.data, simp!(dag.continuation))
        end

    _simp!(dag::SpawnNode{DurationNS}) = SpawnNode{DurationNS}(
        dag.data,
        simp!(dag.detach),
        simp!(dag.continuation),
        simp!(dag.sync),
    )

    _simp!(dag::SyncNode{DurationNS}) =
        if dag.continuation === nothing
            dag
        else
            SyncNode{DurationNS}(simp!(dag.continuation))
        end

    return simp!(dag)
end

# Use 1-depth-first ordering?
function foreachnode(f, dag::DAG)
    seen = IdDict{DAG,Nothing}()
    function visit(dag)
        if !haskey(seen, dag)
            seen[dag] = nothing
            _visit(dag)
        end
        return
    end

    function _visit(dag::SequentialNode)
        f(dag)
        visit(dag.continuation)
    end

    function _visit(dag::SpawnNode)
        f(dag)
        visit(dag.detach)
        visit(dag.continuation)
    end

    function _visit(dag::SyncNode)
        f(dag)
        k = dag.continuation
        if k !== nothing
            visit(k)
        end
    end

    visit(dag)
end
