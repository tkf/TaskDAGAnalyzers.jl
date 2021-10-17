module TestExamples

import ShowGraphviz
import TaskDAGAnalyzers
import TaskDAGRecorders
using TaskDAGAnalyzers: Examples
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

end  # module
