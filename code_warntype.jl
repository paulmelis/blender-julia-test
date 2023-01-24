using InteractiveUtils
include("halfedge.jl")
include("catmull-clark.jl")

code_warntype(build, (Vector{Float32}, Vector{UInt32}, Vector{UInt32}, Vector{UInt32}))

#code_warntype(get_vertex, (Vector{Float32}, UInt32))

#code_warntype(set_vertex, (Vector{Float32}, UInt32, Vector{Float32}))

#code_warntype(subdivide, (Vector{Float32}, Vector{UInt32}, Vector{UInt32}, Vector{UInt32}))
