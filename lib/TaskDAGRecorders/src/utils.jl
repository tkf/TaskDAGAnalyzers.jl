# TODO: Use Preferences?
const DEBUG = true

if DEBUG
    const var"@_debug" = var"@debug"
else
    macro _debug(args...)
    end
end
