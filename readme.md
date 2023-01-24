# Mesh processing with Julia in Blender

Proof-of-concept of using Julia code for doing mesh processing in Blender.

Paul Melis (paul.melis@surf.nl), September 3, 2020

Contributions:
- Speedup using StaticArrays (Kristoffer Carlsson)

## Overview

A test of Catmull-Clark subdivision implemented in Julia, which gets called
from Blender through Python. 

- `catmull-clark.jl`: subdivision implementation
- `halfedge.jl`: half-edge data structure for faster mesh queries
- `test.blend`: example Blender file, contains some Python code to set up
  the mesh data arrays, call the Julia code and process the results.
  
> **Note**
> The Julia code contains only a rudimentary Catmull-Clark implementation, 
> without advanced things like edge sharpness, nor much thought about the design. 
> It will probably not even handle all meshes correctly, especially for the case 
> of boundary edges things might go wrong. But it is also less than 300 lines of 
> code, which is kind of amazing given the performance shown below.

> **Warning
> There currently is an issue when exiting Blender after running the Julia code.
> It seems some memory corruption happens somewhere, as the error `munmap_chunk(): invalid pointer`
> is shown and core is dumped. Haven't investigated yet.
  
## Setup

We use the official binary distribution of Blender 3.4.1 here, as it contains 
a separate `python` binary and allows installation of the necessary Python modules
locally to Blender. This avoids problems of a system-wide Python installation
interfering.

The tests and results shown here use Julia 1.8.5. The Python-Julia interface is 
provided by the [JuliaCall](https://cjdoris.github.io/PythonCall.jl/stable/) package (previously the code used PyCall/PyJulia).

1. Install the `juliacall` package within the Blender distribution directory using:

    ```
    $ ~/blender-3.4.1-linux-x64/3.4/python/bin/python3.10 -m ensurepip
    $ ~/blender-3.4.1-linux-x64/3.4/python/bin/python3.10 -m pip install -U juliacall
    ```

2. Start Blender (making sure to call `~/blender-3.4.1-linux-x64/blender` and not any system-wide `blender`)
and verify in the Python console within Blender that `import juliacall` succeeds:

    ```
    PYTHON INTERACTIVE CONSOLE 3.10.8 (main, Oct 24 2022, 20:47:11) [GCC 9.3.1 20200408 (Red Hat 9.3.1-2)]
    
    Builtin Modules:       bpy, bpy.data, bpy.ops, bpy.props, bpy.types, bpy.context, bpy.utils, bgl, gpu, blf, mathutils
    Convenience Imports:   from mathutils import *; from math import *
    Convenience Variables: C = bpy.context, D = bpy.data
    
    >>> import juliacall
    # This might take a minute...
    >>>
    ```

## Performance

See the `Julia` script in the Blender Text Editor for the code used. Example results[^1]
on the Stanford bunny of 35,947 vertices and 69,451 triangles (on a Core i5 
system @ 3.20 GHZ running Arch Linux):

```
(Blender) Preparing data took 1.878ms
(Julia) Building half edges done in 61.165ms
(Julia) Input: 35947 vertices, 69451 polygons, 104288 polygon edges
(Julia) Output: 209686 vertices, 208353 quads
(Julia) Subdivision done in 31.381ms
(Blender) Call to Julia subdivision function took 457.500ms
(Blender) Updating subdivided mesh took 266.728ms
(Blender) Total time: 726.106ms
```

So 92.546ms (61.165+31.381) is spent in the Julia code doing the actual
subdivision, almost 13% of the total time. The rest of the time is spent on 
marshaling data between Julia and Blender/Python, creating the output mesh
and other overhead. 

Note that when the Julia code is first executed from Blender it might take
quite a bit of time, due to Julia's on-demand native code generation. Subsequent
runs of the code, including after editing part of the Julia source files, will 
be much faster as the compiled code is cached. The timings above are for the second
run of the code.

Accurately comparing with applying a Subdivision Surface modifier on the same mesh 
from within Blender is a bit tricky interactively, as `bpy.ops.object.modifier_add(type='SUBSURF')` 
(see `Blender` script in the Text Editor) returns almost immediately, while the mesh 
is still being subdivided. Running it in batch mode seems to give a more realistic
time:

```
melis@juggle 10:31:~/concepts/blender-julia-test$ ~/software/blender-3.4.1-linux-x64/blender -b test2.blend --python-text Blender 
Blender 3.4.1 (hash 55485cb379f7 built 2022-12-20 00:46:45)
Read prefs: /home/melis/.config/blender/3.4/config/userpref.blend
Read blend: /home/melis/concepts/blender-julia-test/test2.blend
Applying subsurf modifier took 12863.353ms

```

The comparison isn't completely fair as the subsurf modifier probably does a lot
more than just subdivide the mesh, in terms of data structures it builds, judging
by the amount of memory it allocates.

But still, at the default `Levels Viewport` of 1 the number of vertices and
faces in the subdivided model is very similar for the two cases. 

The Julia case is computed **almost 18x faster** and uses significantly less memory 
(again, the latter may be caused by extra things the subsurf modifier stores).


[^1]: There does seem to be quite a bit of variance in the total time spent over 
different runs on my system, I don't really know where that is coming from (the
workstation isn't doing much else and CPU scaling is disabled). 
But the reported time spent on the subdivision in Julia stays below 250ms in 
most cases, with the variance apparently coming from the Blender-Julia boundary.

## Optimization

Basically no effort has been done to optimize the Julia code at this point. 
There probably is lots of potential for improvements. Actually, the code is very 
much written like I would do in Python, using the builtin data types like lists 
and dicts, without too much low-level optimization. Julia is able to generate 
far more efficient compiled code compared to Python's interpreted execution.

Possible optimizations on the Julia side:

- Performance annotations, such as `@inbounds`, `@fastmath` and `@simd`

- Reduce the number of allocations. E.g. for the case above `@time` reports
  `0.255132 seconds (277.99 k allocations: 44.658 MiB, 16.89% gc time)`. The
  high number of allocations is partly caused by having separate `HalfEdge` instances.
  The Bunny model has 104288 edges, leading to roughly double that number of `HalfEdge`'s
  being allocated. Pre-allocating all needed `HalfEdge` instances in a single 
  array would be possible (`sum(loops)` gives the required number). 

- Look more into type stability, `@code_warntype`, etc

- ~~Using StaticArrays.jl in strategic places~~

- Using a 2D array instead of a 1D array for holding vertices, which would
  make get_vertex and set_vertex simpler, but this might not matter much.

The transfer of mesh data between Blender and Julia is far from optimal:

- On the Blender side the mesh data is extracted using calls to `foreach_get()`
  into preallocated NumPy arrays. Perhaps there is a way to directly access
  the underlying data from the mesh object?
  
- Blender (and Python) use 0-based indexing, while Julia uses 1-based indexing.
  We +1/-1 alter the relevant data on the transfer between the two worlds, which
  shouldn't cost that much time, but I don't see an easy way to stick to a single 
  indexing scheme on both sides. Julia has some support for 0-based indexing,
  but it apparently comes with some caveats.
  