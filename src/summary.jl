struct DAGSummary
    ctx::Union{SyncContext,Nothing}
    dag::DAG{DurationNS}
    work::DurationNS
    span::DurationNS
end

TaskDAGAnalyzers.work(s::DAGSummary) = s.work
TaskDAGAnalyzers.span(s::DAGSummary) = s.span

TaskDAGAnalyzers.parallelism(s) =
    Real(TaskDAGAnalyzers.work(s)) / Real(TaskDAGAnalyzers.span(s))

TaskDAGAnalyzers.summary(ctx::SyncContext) = DAGSummary(ctx, TaskDAGAnalyzers.dag(ctx))
TaskDAGAnalyzers.summary(dag::DAG) = DAGSummary(nothing, dag)

function DAGSummary(ctx::Union{SyncContext,Nothing}, dag::DAG)
    work = TaskDAGAnalyzers.work(dag)
    span = TaskDAGAnalyzers.span(dag)
    return DAGSummary(ctx, dag, work, span)
end

function Base.show(io::IO, ::MIME"text/plain", s::DAGSummary)
    print(io, "TaskDAGAnalyzers.summary:")
    print(io, '\n', "work: ", labeltext(s.work))
    printstyled(io, " (single-thread run-time T₁)", color = :light_black)
    print(io, '\n', "span: ", labeltext(s.span))
    printstyled(io, " (theoretical fastest run-time Tₒₒ)", color = :light_black)
    print(io, '\n', "parallelism (work/span): ", TaskDAGAnalyzers.parallelism(s))
end
