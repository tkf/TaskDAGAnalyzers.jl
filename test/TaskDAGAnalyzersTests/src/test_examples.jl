module TestExamples

import ShowGraphviz
import TaskDAGAnalyzers
import TaskDAGRecorders
using TaskDAGAnalyzers: Examples
using TaskDAGAnalyzers.Internal: SpawnNode, SequentialNode, DurationNS, foreachnode
using Test

function check_smoke(f)
    ctx = TaskDAGRecorders.sample(f)
    dag = TaskDAGAnalyzers.dag(ctx)
    dot = ShowGraphviz.DOT(dag)
    src = sprint(show, "text/plain", dot)
    @test occursin("digraph", src)
    txt = sprint(show, "text/plain", TaskDAGAnalyzers.summary(ctx))
    @test occursin("work", txt)
    @test occursin("span", txt)
    @test occursin("parallelism", txt)
end

function test_smoke()
    @testset for f in [Examples.dac, Examples.dac4]
        check_smoke(f)
    end
end

function set_uniform_unit_work!(dag, unit)
    foreachnode(dag) do node
        if node isa SequentialNode
            node.data = unit
        elseif node isa SpawnNode
            node.data = DurationNS(typemax(Int))  # this should be ignored
        end
    end
end

# TODO: don't depend on noisefloor
function check_unit_span(f)
    ctx = TaskDAGRecorders.sample(f, 4)[end]
    dag = TaskDAGAnalyzers.dag(ctx)
    unit = DurationNS(123_456_789)
    set_uniform_unit_work!(dag, unit)
    @test TaskDAGAnalyzers.span(dag) == unit
end

function test_unit_span()
    @testset for f in [Examples.dac, Examples.dac4]
        check_unit_span(f)
    end
end

function test_dac_work()
    ctx = TaskDAGRecorders.sample(Examples.dac, 4)[end]
    dag = TaskDAGAnalyzers.dag(ctx)
    unit = DurationNS(123_456_789)
    set_uniform_unit_work!(dag, unit)
    expected_work = DurationNS(unit.value * 4)
    @test TaskDAGAnalyzers.work(dag) == expected_work
end

function test_dac4_work()
    ctx = TaskDAGRecorders.sample(Examples.dac4, 4)[end]
    dag = TaskDAGAnalyzers.dag(ctx)
    unit = DurationNS(123_456_789)
    set_uniform_unit_work!(dag, unit)
    expected_work = DurationNS(unit.value * 16)
    @test TaskDAGAnalyzers.work(dag) == expected_work
end

end  # module
