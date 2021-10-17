import TaskDAGRecorders
const DAGr = TaskDAGRecorders

function dac(depth = 2)
    function f(n)
        if n <= 1
            sleep(0.01)
        else
            DAGr.@sync begin
                DAGr.@spawn f(n ÷ 2)
                f(n ÷ 2)
            end
        end
    end
    f(2 ^ depth)
end

function dac4(depth = 2)
    function f(n)
        if n <= 1
            sleep(0.01)
        else
            DAGr.@sync begin
                DAGr.@spawn f(n ÷ 4)
                DAGr.@spawn f(n ÷ 4)
                DAGr.@spawn f(n ÷ 4)
                f(n ÷ 4)
            end
        end
    end
    f(4 ^ depth)
end
