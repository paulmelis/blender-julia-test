import numpy, ctypes
import julia
from julia.api import Julia

jl = Julia()
from julia import Main

jl.eval('include("alter_array.jl")')

a = numpy.array([1, 2, 3, 4, 5], 'uint32')
print(a)

addr = a.ctypes.data
length = a.shape[0]

Main.fn(a)
print(a)

Main.fn(addr, length)
print(a)
