import numpy
print(numpy.__file__)
print(numpy.__version__)

import julia
print(julia.__file__)
print(julia.__version__)
from julia.api import Julia

print('Initializing Julia (this might take a moment the first time)...')
jl = Julia(compiled_modules=False)
print('Done!')

# Needs to come after the creation of the Julia instance above
from julia import Main

jl.eval('include("return_array.jl")')

res = Main.fn()

print(type(res))
print(res)

print('item 0 =', type(res[0]))
