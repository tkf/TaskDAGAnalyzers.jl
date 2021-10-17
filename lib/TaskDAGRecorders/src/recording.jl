const sync_context = gensym(:sync_context)

macro sync(ex)
    ctx = esc(sync_context)
    ex = esc(Expr(:block, __source__, ex))
    quote
        let $ctx = push_context()
            ans = $ex
            pop_context($ctx)
            ans
        end
    end
end

macro spawn(ex)
    ctx = esc(sync_context)
    ex = esc(Expr(:block, __source__, ex))
    quote
        $(Expr(:isdefined, ctx)) || unsupported_error()
        let ans, stat = start_task!($ctx)
            ans = $ex
            stop_task!($ctx, stat)
            FakeTask(ans)
        end
    end
end

abstract type AbstractContext end

# TODO: Include GC?
mutable struct TaskStat
    start::typeof(time_ns())
    stop::typeof(time_ns())

    TaskStat() = new(0, 0)
end

# TODO: Record calling function?
mutable struct SyncContext <: AbstractContext
    parent::Union{Nothing,AbstractContext}
    children::Vector{AbstractContext}
    stat::TaskStat
end

mutable struct TaskContext <: AbstractContext
    parent::SyncContext
    children::Vector{SyncContext}
    stat::TaskStat
end

function new_child!(parent::AbstractContext, ::Type{Ctx}) where {Ctx<:AbstractContext}
    child = Ctx(parent)
    push!(parent.children, child)
    return child
end

const AnyContext = Union{SyncContext,TaskContext}

SyncContext(ctx = nothing) = SyncContext(ctx, [], TaskStat())
start_stat!(ctx::SyncContext) = start_stat!(ctx.stat)
stop_stat!(ctx::SyncContext) = stop_stat!(ctx.stat)

TaskContext(ctx::SyncContext) = TaskContext(ctx, [], TaskStat())

mutable struct TaskDAGRecorder
    current::AnyContext
    root::AnyContext
end

function TaskDAGRecorder()
    ctx = SyncContext()
    ctx.stat.stop = typemax(ctx.stat.stop)
    return TaskDAGRecorder(ctx, ctx)
end

const RECORDER_KEY = :__TASK_DAG_RECORDER_KEY__

get_recorder() = task_local_storage(RECORDER_KEY)::TaskDAGRecorder

function TaskDAGRecorders.sample(f)
    recorder = TaskDAGRecorder()
    task_local_storage(RECORDER_KEY, recorder) do
        start_stat!(recorder.root)
        f()
        stop_stat!(recorder.root)
    end
    return recorder.root
end

function push_context()
    recorder = _get!(TaskDAGRecorder, task_local_storage(), RECORDER_KEY)::TaskDAGRecorder
    ctx = new_child!(recorder.current, SyncContext)
    @_debug "-> sync: $(objectid(ctx))"
    recorder.current = ctx
    start_stat!(ctx)
    return ctx
end

function pop_context(ctx::SyncContext)
    stop_stat!(ctx)
    @_debug "<- sync: $(objectid(ctx))"
    recorder = get_recorder()
    @assert recorder.current === ctx
    recorder.current = ctx.parent
    return
end

function start_stat!(stat::TaskStat)
    stat.start = time_ns()
    return stat
end

function stop_stat!(stat::TaskStat)
    stat.stop = time_ns()
    return stat
end

function start_task!(ctx::SyncContext)
    recorder = get_recorder()
    if recorder.current !== ctx
        @_debug "recorder.current: $(objectid(recorder.current)) != ctx: $(objectid(ctx))"
    end
    @assert recorder.current === ctx
    task = new_child!(recorder.current, TaskContext)
    recorder.current = task
    @_debug "-> spawn: $(objectid(task)) in $(objectid(ctx))"
    start_stat!(task.stat)
    return task
end

function stop_task!(ctx::SyncContext, task::TaskContext)
    recorder = get_recorder()
    if recorder.current !== task
        @_debug "recorder.current: $(objectid(recorder.current)) != task: $(objectid(task))"
    end
    @assert recorder.current === task
    @assert task.parent === ctx
    recorder.current = ctx
    stop_stat!(task.stat)
    @_debug "<- spawn: $(objectid(task)) in $(objectid(ctx))"
end

struct FakeTask
    result::Any
end

Base.fetch(t::FakeTask) = t.result
Base.wait(::FakeTask) = nothing

function unsupported_error()
    error("`@spawn` without `@sync` is not supported")
end

"""
    TaskDAGRecorders.sample(f) -> context
    TaskDAGRecorders.sample(f, n::Integer) -> contexts::Vector

Log tasks (span and sync operations) while executing `f`. The code executed in
`f` must be instrumented by `using TaskDAGRecorders: @sync, Threads`.

The unary method runs `f` once and return a single `context` that records the
task operations.

The binary method runs `f` repeatedly `n` times and return a vector of contexts
that record the task operations.

Use `TaskDAGAnalyzers.dag` to convert this into a DAG representation.
"""
TaskDAGRecorders.sample

function TaskDAGRecorders.sample(f, n::Integer)
    samples = Vector{SyncContext}(undef, n)
    for i in 1:n
        samples[i] = TaskDAGRecorders.sample(f)
    end
    return samples
end

function get_sync_context(recorder = get_recorder())
    ctx = recorder.root
    if ctx isa SyncContext
        if length(ctx) == 0
            return ctx
        elseif length(ctx.children) == 1
            child, = ctx.children
            if child isa SyncContext
                return child
            else
                return ctx
            end
        end
        stat = TaskStat()
        stat.start = ctx.children[1].start
        stat.stop = ctx.children[end].stop
        return SyncContext(nothing, ctx.children, stat)
    elseif ctx isa TaskContext
        error("unexpected TaskContext")
    end
    error("unreachable")
end
