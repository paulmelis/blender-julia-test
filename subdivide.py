#
# Make sure a mesh object to be subdivided is selected before running this script
#

import bpy, time
import numpy

scene = bpy.context.scene

from julia.api import Julia

print('Initializing Julia (this might take a moment the first time)...')
# The compiled_modules option is to work around the fact that libpython
# is linked statically in Blender.
# https://pyjulia.readthedocs.io/en/latest/troubleshooting.html#your-python-interpreter-is-statically-linked-to-libpython
jl = Julia(compiled_modules=False)
print('Done!')

# Needs to come after the creation of the Julia instance above
from julia import Main

jl.eval('include("catmull-clark.jl")')

# Delete previous output mesh

if 'subdivided' in bpy.data.objects:
    bpy.ops.object.select_all(action='DESELECT')
    bpy.data.objects['subdivided'].select_set(True)
    bpy.ops.object.delete()

#
# Get current mesh data
#

#obj = bpy.data.objects['Cube']
obj = bpy.context.active_object
if obj is None:
    print('ERROR: No object selected!')
    doh
    
msh = obj.data

t0 = time.time()

# Get mesh data as numpy arrays, as we cannot access these values
# directly. Only the vertices are really present in a Blender mesh
# as a single linear array, the other values are stored with each
# polygon. The foreach_get() calls below gather them into an array
# per value.

num_vertices = len(msh.vertices)
num_polygons = len(msh.polygons)
num_loops = len(msh.loops)

vertices = numpy.empty(num_vertices*3, 'float32')
msh.vertices.foreach_get('co', vertices)

loop_start = numpy.empty(num_polygons, 'uint32')
msh.polygons.foreach_get('loop_start', loop_start)

loop_total = numpy.empty(num_polygons, 'uint32')
msh.polygons.foreach_get('loop_total', loop_total)

loops = numpy.empty(num_loops, 'uint32')
msh.loops.foreach_get('vertex_index', loops)

t1 = time.time()
print('(Blender) Preparing data took %.3fms' % (1000*(t1-t0)))

#
# Call julia function on the mesh data
#
# Note: we turn Blender's 0-based indices into Julia's 
# 1-based indices to avoid a whole load of +/- 1 fiddling on the Julia side

new_vertices, new_loop_start, new_loop_total, new_loops = \
    Main.subdivide(vertices, loop_start+1, loop_total, loops+1)
    
#print(new_vertices, new_loop_start, new_loop_total, new_loops)
#print(type(new_vertices))

# For @time information
#new_vertices, new_loop_start, new_loop_total, new_loops = \
#    Main.time_subdivide(vertices, loop_start+1, loop_total, loops+1)
    
t2 = time.time()
print('(Blender) Call to Julia subdivision took %.3fms' % (1000*(t2-t1)))

# XXX We get back lists instead of numpy arrays with Blender's numpy.
# Should find a way to fix that, see
# https://github.com/paulmelis/blender-julia-test/issues/2

if isinstance(new_vertices, list):
    # XXX workaround for issue#2 for now
    # List to numpy arrays
    new_vertices = numpy.array(new_vertices, 'float32')
    new_loop_total = numpy.array(new_loop_total, 'uint32')
    # Back to 0-based indexing
    new_loop_start = numpy.array(new_loop_start, 'uint32') - 1
    new_loops = numpy.array(new_loops, 'uint32') - 1
else:
    # Back to 0-based indexing
    new_loop_start -= 1
    new_loops -= 1

num_new_vertices = new_vertices.shape[0] // 3

mesh2 = bpy.data.meshes.new(name='subdivided')

mesh2.vertices.add(num_new_vertices)
mesh2.vertices.foreach_set("co", new_vertices)

mesh2.loops.add(new_loops.shape[0])
mesh2.loops.foreach_set("vertex_index", new_loops)

mesh2.polygons.add(new_loop_start.shape[0])
mesh2.polygons.foreach_set("loop_start", new_loop_start)
mesh2.polygons.foreach_set("loop_total", new_loop_total)

mesh2.update()
mesh2.validate()

obj2 = bpy.data.objects.new('subdivided', mesh2)
scene.collection.objects.link(obj2)

bpy.ops.object.select_all(action='DESELECT')
obj2.select_set(True)
bpy.context.view_layer.objects.active = obj2

t3 = time.time()
print('(Blender) Updating subdivided mesh took %.3fms' % (1000*(t3-t2)))
print('(Blender) Total time: %.3fms' % (1000*(t3-t0)))
