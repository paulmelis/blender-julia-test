function fn(x::Array{Float32})
    println("array size: $(size(x))");
    println("max element: $(maximum(x))")
    println("min element: $(minimum(x))")
    x[1,1] = 123
    #return 2x
end
