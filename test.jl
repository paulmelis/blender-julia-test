# https://discourse.julialang.org/t/calling-julia-functions-from-python/6885/2
function myArrayFn(x::Array{T}) where T
    println("array size: $(size(x))");
    println("max element: $(maximum(x))")
    println("min element: $(minimum(x))")
    x[1,1] = 123
    return 2x
end