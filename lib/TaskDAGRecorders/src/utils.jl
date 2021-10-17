# TODO: Use Preferences?
const DEBUG = true

if !isdefined(Base, Symbol("@var_str"))
    macro var_str(s)
        Symbol(s)
    end
end

if DEBUG
    const var"@_debug" = var"@debug"
else
    macro _debug(args...)
    end
end
