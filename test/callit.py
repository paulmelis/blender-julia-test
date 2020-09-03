import time, gc
import numpy

from julia.api import Julia
from julia import Main

jl = Julia(compiled_modules=False)
jl.eval("""
include("fn.jl")

import Base.convert

""")

print('allocating')

print(gc.get_stats())

x = numpy.ones(200*1024*1024, 'float32')

#x = numpy.array([1,2,3,4,5,6], dtype=numpy.float32)
#print(x)

time.sleep(5)

print('calling into Julia')
Main.fn(x)

print('Back in Python')
time.sleep(5)

print('Attempting to clean up')
del x
print(gc.get_stats())

time.sleep(5)

#print(x)
