module TestExamples

import ShowGraphviz
import TaskDAGRecorders
using TaskDAGAnalyzers: Examples
using Test

function check_smoke(f)
    ctx = TaskDAGRecorders.sample(f)
    dag = TaskDAGRecorders.dag(ctx)    
    dot = ShowGraphviz.DOT(dag)
    src = sprint(show, "text/plain", dot)
    @test occursin("digraph", src)
end

function test_smoke()
    @testset for f in [Examples.dac, Examples.dac4]
        check_smoke(f)
    end
end

end  # module
