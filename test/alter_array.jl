function fn(a)
    a[:] .= 9
end

function fn(addr, length)
    a = unsafe_wrap(Array{UInt32}, Ptr{UInt32}(addr), length)
    fn(a)
end
