import time, gc
import numpy

from julia.api import Julia
from julia import Main

jl = Julia(compiled_modules=False)
jl.eval("""
include("return_array.jl")
""")

print('calling into Julia')
res = Main.fn(123)

print('Back in Python')
for v in res:
    print(type(v))
    print(v)
