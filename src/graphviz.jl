function Base.show(io::IO, ::MIME"text/vnd.graphviz", dag::DAG)
    idref = Ref(0)
    newid() = idref[] += 1

    idmap = IdDict{DAG,Int}()
    idfor(dag) = get!(newid, idmap, dag)

    seen = IdDict{DAG,Nothing}()
    function isseen(dag)
        yes = Ref(true)
        get!(seen, dag) do
            yes[] = false
            nothing
        end
        return yes[]
    end

    prln(args...) = println(io, "  ", args...)

    function draw(dag::SequentialNode, id)
        isseen(dag) && return
        txt = labeltext(dag.data)
        prln(id, " [shape=record, label=\"$txt\"];")
        kid = idfor(dag.continuation)
        prln(id, " -> ", kid, ";")
        draw(dag.continuation, kid)
    end

    function draw(dag::SpawnNode, id)
        isseen(dag) && return
        sid = idfor(dag.sync)
        did = idfor(dag.detach)
        kid = idfor(dag.continuation)
        prln(id, " [shape=egg, label=\"spawn (in $sid)\"];")
        prln(id, " -> ", did, " [label = Det];")
        prln(id, " -> ", kid, " [label = Cont];")
        draw(dag.detach, did)
        draw(dag.continuation, kid)
    end

    function draw(dag::SyncNode, id)
        isseen(dag) && return
        k = dag.continuation
        if k isa DAG
            prln(id, " [shape=diamond, label=\"sync $id\"];")
            kid = idfor(k)
            prln(id, " -> ", kid, ";")
            draw(k, kid)
        end
    end

    println(io, "digraph DAG {")
    draw(dag, newid())
    print(io, "}")
end

function labeltext(data::DurationNS)
    if data.value > 1e9
        x = data.value / 1e9
        u = "s"
    elseif data.value > 1e6
        x = data.value / 1e6
        u = "ms"
    elseif data.value > 1e3
        x = data.value / 1e3
        u = "μs"
    else
        x = data.value
        u = "ns"
    end
    i, f = divrem(x, 1)
    i = floor(Int, i)
    if i > 10
        return "$i $u"
    else
        j = floor(Int, 10 * f)
        return "$i.$j $u"
    end
end

ShowGraphviz.@deriveall DAG
