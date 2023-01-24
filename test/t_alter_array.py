import numpy
import julia
from julia.api import Julia

jl = Julia()
from julia import Main

jl.eval('include("alter_array.jl")')

a = numpy.array([1, 2, 3, 4, 5], 'uint32')
print(a)

#Main.fn(a)
#print(a)

#addr = a.ctypes.data
#length = a.shape[0]
#Main.fn(addr, length)
#print(a)

# Leads to https://github.com/JuliaPy/pyjulia/issues/414
#pyfn = Main.PyCall.pyfunction(Main.fn, Main.PyCall.PyArray)

# https://discourse.julialang.org/t/pyjulia-passing-numpy-array-from-python-side/45894/12
pyfn = Main.eval("pyfunction(fn, PyArray)")
print(pyfn)

pyfn(a)
print(a)
