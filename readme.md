# Mesh processing with Julia in Blender

Proof-of-concept of using Julia code for doing mesh processing in Blender.

Paul Melis (paul.melis@surf.nl), September 3, 2020

## Overview

A test of Catmull-Clark subdivision implemented in Julia, which gets called
from Blender through Python. 

- `catmull-clark.jl`: subdivision implementation
- `halfedge.jl`: half-edge data structure for faster mesh queries
- `test.blend`: example Blender file, contains some Python code to set up
  the mesh data arrays, call the Julia code and process the results.
  
Note: the Julia code contains only a rudimentary Catmull-Clark implementation, 
without advanced things like edge sharpness, nor much thought about the design. 
It will probably not even handle all meshes correctly, especially for the case 
of boundary edges things might go wrong. But it is also less than 300 lines of 
code, which is kind of amazing given the performance shown below.
  
Requirements:
- Blender 2.90 (older might work as well)
- Julia 1.5 with the [PyJulia](https://github.com/JuliaPy/pyjulia) package 
  installed. The easiest way to get this into Blender is to run 

    ```
    $ <blender-dir>/2.90/python/bin/python3.7m -m ensurepip --user
    $ <blender-dir>/2.90/python/bin/python3.7m -m pip install -U julia --user
    ```
    
  and then verify in the Python console within Blender that `import julia` succeeds.
  
## Performance

See the `Julia` script in the Text Editor for the code used. Example results
on the Stanford bunny of 35,947 vertices and 69,451 triangles (on a Core i5 
system @ 3.20 GHZ running Arch Linux):

```
(Blender) Preparing data took 1.246ms
(Julia) Building half edges done in 100.423ms
(Julia) Input: 35947 vertices, 69451 polygons, 104288 polygon edges
(Julia) Output: 209686 vertices, 208353 quads
(Julia) Subdivision done in 284.266ms
(Blender) Call to Julia subdivision took 1093.536ms
(Blender) Updating subdivided mesh took 366.968ms
(Blender) Total time: 1461.751ms
```

So 384.689ms (100.423+284.266) is spent in the Julia code doing the actual
subdivision, less than 27%. The rest of the time is spent on marshaling data 
between Julia and Blender/Python and other overhead*. 

Applying a Subdivision Surface modifier on the same mesh from within Blender
(the `Blender` script in the Text Editor):

```
Applying subsurf modifier took 13583.849ms
```

The comparison isn't completely fair as the subsurf modifier probably does a lot
more than just subdivide the mesh, in terms of data structures it builds, judging
by the amount of memory it allocates.

But still, at the default `Levels Viewport` of 1 the number of vertices and
faces in the subdivided model is exactly the same for the two cases. 

The Julia case is computed **more than 9x faster** and uses significantly less memory 
(again, the latter may be caused by extra things the subsurf modifier stores).

Note that when the Julia code is first executed from Blender it might take
quite a bit of time, due to Julia's on-demand code compilation. Subsequent
runs of the code, including after editing the Julia source files, will be much
faster as the compiled code is cached.

* There does seem to be quite a bit of variance in the total time spent over 
different runs, don't really know where that is coming from. But the reported time 
spent on the subdivision in Julia stays below 400ms in most cases, with the 
variance apparently coming from the Blender-Julia boundary.

## Optimization

Basically no effort has been done to optimize the Julia code at this point. 
There probably is lots of potential for improvements. Actually, the code is very 
much written like I would do in Python, using the builtin data types like lists 
and dicts, without too much low-level optimization. Julia is able to generate 
far more efficient compiled code compared to Python's interpreted execution.

Possible optimizations on the Julia side:

- Performance annotations, such as `@inbounds`, `@fastmath` and `@simd`
- Look into type stability, `@code_warntype`, etc
- Using StaticArrays.jl in strategic places
- Using a 2D array instead of a 1D array for holding vertices, which would
  make get_vertex and set_vertex simpler, but this might not matter much.

The transfer of mesh data between Blender and Julia is far from optimal:

- On the Blender side the mesh data is extracted using calls to `foreach_get()`
  into preallocated NumPy arrays. Perhaps there is a way to directly access
  the underlying data from the mesh object?
- Even though the Julia code returns a set of `Array{Float32}` values these
  get turned into Python lists when crossing the boundary to Blender. Which are 
  then turned into NumPy arrays on the Blender side for setting up the result mesh.
  All in all there's quite a lot of copying going on.
- Blender (and Python) use 0-based indexing, while Julia uses 1-based indexing.
  We +1/-1 alter the relevant data on the transfer between the two worlds, which
  shouldn't cost that much time, but I don't see an easy way to stick to a single 
  indexing scheme on both sides. Julia has some support for 0-based indexing,
  but it apparently comes with some caveats.
- PyJulia uses the Julia PyCall package for data conversion between Python and Julia,
  which should be able to use zero-copy transfer between the two, judging by 
  https://github.com/JuliaPy/PyCall.jl#arrays-and-pyarray. But so far that
  does not seem to be what really happens, e.g. https://github.com/JuliaPy/pyjulia/issues/385
  