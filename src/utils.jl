# Use README as the docstring of the module:
function define_docstring()
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    doc = replace(read(path, String), r"^```julia"m => "```jldoctest README")
    @eval TaskDAGAnalyzers $Base.@doc $doc TaskDAGAnalyzers
end
