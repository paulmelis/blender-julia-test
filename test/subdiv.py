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

jl.eval('include("../catmull-clark.jl")')

vertices = numpy.array([-1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0], 'float32')
loop_start = numpy.array([0x00000001, 0x00000005, 0x00000009, 0x0000000d, 0x00000011, 0x00000015], 'uint32')
loop_total = numpy.array([0x00000004, 0x00000004, 0x00000004, 0x00000004, 0x00000004, 0x00000004], 'uint32')
loops = numpy.array([0x00000001, 0x00000002, 0x00000004, 0x00000003, 0x00000003, 0x00000004, 0x00000008, 0x00000007, 0x00000007, 0x00000008, 0x00000006, 0x00000005, 0x00000005, 0x00000006, 0x00000002, 0x00000001, 0x00000003, 0x00000007, 0x00000005, 0x00000001, 0x00000008, 0x00000004, 0x00000002, 0x00000006], 'uint32')

res = Main.subdivide(vertices, loop_start, loop_total, loops)

for v in res:
    print(type(v))
    print(v)
