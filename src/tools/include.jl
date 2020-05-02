
include("iteration.jl")
include("constants.jl")
include("math.jl")

include("linalg.jl")
include("vec3.jl")
include("quaternion.jl")
include("tensors.jl")

include("table.jl")
include("expr.jl")
include("show.jl")
include("stopwatch.jl")
include("sound.jl")
include("xml.jl")

include("tex.jl")

Base.show(io::IO, obj::Xnode) = custom_dump(io, obj, 3, "")
Base.show(io::IO, obj::Xdoc) = custom_dump(io, obj, 3, "")
