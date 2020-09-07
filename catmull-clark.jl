# Copyright 2020 Paul Melis (paul.melis@surf.nl)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using Printf
using StaticArrays

include("halfedge.jl")

# Some utility functions to handle Julia's 1-based indexing
function get_vertex(V, idx)
    s = 1+3*(idx-1)
    return SVector(V[s], V[s+1], V[s+2])
end

function set_vertex(V, idx, v)
    s = 1+3*(idx-1)
    V[s:s+2] = v
end

function time_subdivide(vertices::Array, loop_start::Array, loop_total::Array, loops::Array)
    @timev subdivide(vertices, loop_start, loop_total, loops)
end

function subdivide(vertices::Array, loop_start::Array, loop_total::Array, loops::Array)
    #println(vertices)
    #println(loop_start)
    #println(loop_total)
    #println(loops)
    
    t0 = time()
    
    num_vertices, num_faces, num_edges, vertex_start_edges, face_start_edges, polygon_edges = build(vertices, loop_start, loop_total, loops)
    
    t1 = time()
    @printf("(Julia) Building half edges done in %.3fms\n", 1000*(t1-t0))
    
    println("(Julia) Input: $(num_vertices) vertices, $(num_faces) polygons, $(num_edges) polygon edges")
        
    # One new vertex for each input face, one new vertex for each edge
    output_num_vertices = num_vertices + num_faces + num_edges
    # 1 .. NV           Original input vertices (initially, are overwritten later on)
    # NV+1 .. NV+NF     New face points 
    # NV+NF+1 .. end    New edge points    
    output_vertices = Array{Float32}(undef, 3*output_num_vertices)
    # Copy original input vertex positions, to be modified later on
    output_vertices[1:3*num_vertices] = vertices
    
    # Output is always all quads, as each input face is split into n quads, 
    # where n is the number of vertices in the face
    output_num_quads = sum(loop_total)
    output_loop_start = collect(range(UInt32(1), step=UInt32(4), stop=UInt32(output_num_quads*4)))
    output_loop_total = fill(UInt32(4), output_num_quads)   
    output_loops = Array{UInt32}(undef, 4*output_num_quads)
    
    println("(Julia) Output: $(output_num_vertices) vertices, $(output_num_quads) quads")   
    
    function face_point_index(fi)
        return num_vertices + fi
    end

    function edge_point_index(ei)
        return num_vertices + num_faces + ei
    end

    #
    # Subdivide
    #
    
    # Add new face points: average of existing original face vertices
    for fi = 1:num_faces
        sum = SVector{3, Float32}(0.0, 0.0, 0.0)
        n = 0
        
        he = start = face_start_edges[fi]
        while true
            sum += get_vertex(vertices, he.source)
            n += 1
            
            he = he.next            
            if he == start break end
        end
        
        set_vertex(output_vertices, face_point_index(fi), sum / n)
        
    end
    
    #println("FV ", face_vertices)
    #println("OV ", output_vertices)
    
    # Add new edge points: average of edge endpoints and neighbouring face points
    
    for ei = 1:num_edges
        
        he = polygon_edges[ei]        
        
        edge_point = (
            get_vertex(output_vertices, face_point_index(he.face))
            +
            get_vertex(output_vertices, he.source)
            +
            get_vertex(output_vertices, he.target)
        )        
        n = 3
        
        he = he.sibling
        if he != nothing            
            edge_point += get_vertex(output_vertices, face_point_index(he.face))
            n += 1
        end
        
        set_vertex(output_vertices, edge_point_index(ei), edge_point / n)
    end

    # Move original input vertices to new positions
    
    for vi = 1:num_vertices
    
        if !haskey(vertex_start_edges, vi)
            # Skip unconnected vertices
            continue
        end
                
        P = get_vertex(output_vertices, vi)
        F_sum = SVector{3, Float32}(0, 0, 0)
        R_sum = SVector{3, Float32}(0, 0, 0)
        n = 0
        
        he = start = vertex_start_edges[vi]
        while true
            F_sum += get_vertex(output_vertices, face_point_index(he.face))
            # XXX could take out P here and use it once in R= below
            R_sum += 0.5f0 * (P + get_vertex(output_vertices, he.target))
            n += 1
            
            # XXX need to recheck this works correctly
            if he.sibling == nothing break end
            
            he = he.sibling.next
            if he == start break end
        end
                
        F = F_sum / n
        R = R_sum / n
        
        set_vertex(output_vertices, vi, (F + 2*R + (n-3)*P) / n)        
    end
    
    # Create new face loops for the quads for each subdivided original face
    
    offs = 1
    ofi = 1
    
    for fi = 1:num_faces
    
        he = start = face_start_edges[fi]
        while true
            output_loop_start[ofi] = offs          
            output_loops[offs] = edge_point_index(he.index)
            output_loops[offs+1] = he.target
            output_loops[offs+2] = edge_point_index(he.next.index)
            output_loops[offs+3] = face_point_index(he.face)
            offs += 4
            ofi += 1
            
            he = he.next            
            if he == start break end
        end            
    end
    
    t2 = time()
    @printf("(Julia) Subdivision done in %.3fms\n", 1000*(t2-t1))
    
    return output_vertices, output_loop_start, output_loop_total, output_loops
end
