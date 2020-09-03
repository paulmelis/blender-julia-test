using InteractiveUtils

function fn(n)
    a = Array{Float32}(undef, 5)
    a .= n
    b = Array{UInt32}([n, n, n, n, n])
    c = Array{UInt32}([n, n, n, n, n])
    d = Array{UInt32}([n, n, n, n, n])
    return a, b, c, d
end

code_warntype(fn, (UInt32,))