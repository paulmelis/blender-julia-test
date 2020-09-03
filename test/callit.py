from julia.api import Julia
from julia import Main

jl = Julia(compiled_modules=False)
jl.eval('include("fn.jl")')

import numpy

x = numpy.array([[1,2,3], [4,5,6]], dtype=np.float32)

print(x)
res = Main.fn(x)
print(x)
