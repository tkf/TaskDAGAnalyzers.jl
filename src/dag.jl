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

duration(stat::TaskStat) = DurationNS(stat.stop - stat.start)
duration(pre::TaskStat, post::TaskStat) = DurationNS(post.start - pre.stop)

DAG(ctx::SyncContext) = DAG{DurationNS}(duration, ctx)

# TODO: generalize to arbitrary "weight"
function span(dag::DAG{DurationNS})
    parent = 0
    maxchild = 0
    while true
        if dag === nothing
            break
        elseif dag isa SpawnNode
            maxchild = max(maxchild, dag.data.value)
        elseif dag isa SequentialNode
            parent += dag.data.value
        else
            dag::SyncNode
        end
        dag = dag.continuation
    end
    return max(parent, maxchild)
end

function simplify!(dag::DAG{DurationNS}; noisefloor::Real = 0.01)
    noisefloor == 0 && return dag
    0 ≤ noisefloor ≤ 1 || error("invalid `noisefloor`: ", noisefloor)
    noisefloor_ns = span(dag) * noisefloor

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
