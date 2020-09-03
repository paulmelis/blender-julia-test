
function fn(x::Array{Float32})
    println("array size: $(size(x))");
    
    sleep(5)
    x[1:3] .= -1
end
