# TaskDAGAnalyzers

TaskDAGAnalyzers.jl is an intrusive profiler/analyzer for (strictly) nested
parallel Julia programs.  It can be used to reconstruct the "task DAG" and
related metrics such as *span*, *work*, and *parallelism*.  It reveals the
intrinsic structure in the program without actually running it in parallel.  In
fact, the recording step of TaskDAGAnalyzers.jl is done using single CPU (see
below).  As such, the information obtained from TaskDAGAnalyzers.jl is free from
non-deterministic noise from the task schedulers.

Ref:
[What the $#@! is Parallelism, Anyhow? - Cprogramming.com](https://www.cprogramming.com/parallelism.html)

## Applicability

TaskDAGAnalyzers.jl can only be used for "strictly" nested parallel program
(also known as
*[fork-join](https://en.wikipedia.org/wiki/Fork%E2%80%93join_model)
parallelism*,
*[series-parallel](https://en.wikipedia.org/wiki/Series%E2%80%93parallel_graph)
DAG*, or simply *nested parallelism*). In particular, TaskDAGAnalyzers.jl can be
used with programs that:

* only use `@sync` and `@spawn`, and
* do not refer to the `Task` object.

For example, the following program is supported

```julia
@sync begin
    Threads.@spawn f()
    g()
end
```

However, the following program is not supported

```julia
t1 = Threads.@spawn f1()
t2 = Threads.@spawn begin
    f2()
    wait(t1)
    f3()
end
f4()
wait(t1)
wait(t2)
```

## Usage

### Step 1: Instrumentation

TaskDAGAnalyzers.jl requires instrumentation. Typically, it requires adding
the following line:

```julia
module MyPackage
using TaskDAGRecorders: Threads, @sync  # introduce instrumentation
...
end
```

This line replaces the module `Base.Threads` and the macro `Base.@sync` with the
version defined in TaskDAGRecorders.jl.  TaskDAGRecorders.jl is a minimal
supporting package for TaskDAGAnalyzers.jl.  It is used for logging task
operations.  Note that TaskDAGRecorders.jl runs on a single CPU.

### Step 2: Sampling

Functions using `Threads` API can now be run via `TaskDAGRecorders.sample` to
log task operations.  It may be a good idea to run `TaskDAGRecorders.sample`
once first for ignoring the compilation times.

```julia
using TaskDAGRecorders
using MyPackage
ctx = TaskDAGRecorders.sample() do
    MyPackage.some_threaded_function()
end
```

### Step 3: Analysis

The context object `ctx` above logs the task operations (`@spawn` and `@sync`).
Use `TaskDAGAnalyzers.summary` to get an overview:

```julia
using TaskDAGAnalyzers
TaskDAGAnalyzers.summary(ctx)
```

The DAG can be visualized using Graphviz.

```julia
dag = TaskDAGAnalyzers.dag(ctx)

using FileIO
save("dag.png", dag)
save("dag.svg", dag)
save("dag.pdf", dag)
```
