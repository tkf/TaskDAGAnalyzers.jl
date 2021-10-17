# TODO: Use Preferences?
const DEBUG = true

if !isdefined(Base, Symbol("@var_str"))
    macro var_str(s)
        Symbol(s)
    end
end

macro noop(args...)
end

if DEBUG
    const var"@_debug" = var"@debug"
    const var"@_assert" = var"@assert"
else
    const var"@_debug" = var"@noop"
    const var"@_assert" = var"@noop"
end

const KEY_SENTINEL = Symbol("!!__TASKDAGRECORDERS_KEY_SENTINEL__!!")

"""
Like `get!(f, d, k)`, but safe to mutate `f` in `d` except for the slot `k`.
"""
function _get!(f, d, k)
    y = get(d, k, KEY_SENTINEL)
    if y === KEY_SENTINEL
        y = f()
        @_assert !haskey(d, k)
        d[k] = y
        return y
    else
        return y
    end
end
