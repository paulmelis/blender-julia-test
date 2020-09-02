# vertices making up a face -> loops (plus loop_start and loop_total)
#
# edges making up a face -> ? can iterate over vertex pairs to get edge key
#
# faces using a vertex -> ?

# Some utility functions to handle Julia's 1-based indexing
function get_vertex(V, idx)
    s = 1+3*(idx-1)
    return V[s:s+2]
end

function set_vertex(V, idx, v)
    s = 1+3*(idx-1)
    V[s:s+2] = v
end

function add_edge_face(edge_faces, A, B, left_face_index)
    #println("add_edge_face ", A, " ", B, " ", left_face_index)
    edge_key = (A,B)
    @assert !haskey(edge_faces, edge_key)
    edge_faces[edge_key] = left_face_index
end

const Edge = Tuple{Int32,Int32}
const Face = Int32
const FacePair = Tuple{Face,Face}
const Vec3 = Vector{Float32}          # StaticArray?

function subdivide(vertices::Array, loop_start::Array, loop_total::Array, loops::Array)
    #println(vertices)
    #println(loop_start)
    #println(loop_total)
    #println(loops)
    
    num_vertices = trunc(UInt32, length(vertices) / 3)
    num_faces = length(loop_start)
    println("Input: $(num_vertices) vertices, $(num_faces) quads")
    
    # Build some useful indexes
        
    # "Left face" for each edge (A,B). Left is as seen from the edge A -> B, 
    # i.e. CCW order when viewed from the front
    # Can have both edge (A,B) and (B,A)
    edge_faces = Dict{Edge, Face}()     
    
    # A unique index (1..) for each edge (A,B), for A<B only
    edge_indices = Dict{Edge, Int32}()              
    
    # A+B of input edges, indexed by edge (A,B) with A<B
    edge_endpoint_sum = Dict{Edge, Array{Float32}}()
    
    next_edge_index = num_vertices + num_faces + 1
    
    for fi = 1:num_faces
        ls = loop_start[fi]
        nv = loop_total[fi]  
        loop = loops[ls:ls+nv-1]
        
        # Loop over all edges of this face
        for i = 0:nv-1
            cur = i+1
            next = (i+1) % nv + 1
            
            A = loop[cur]
            B = loop[next]
            
            # Left face
            add_edge_face(edge_faces, A, B, fi)
            
            # Edge index
            if A < B
                key = (A,B)
                edge_endpoint_sum[key] = get_vertex(vertices, A) + get_vertex(vertices, B)
            else
                key = (B,A)
            end
            
            if !haskey(edge_indices, key)
                index = edge_indices[key] = next_edge_index
                next_edge_index += 1
            end                        
        end
    end
    
    #println("edge_faces ", edge_faces)
    #println("edge_indices ", edge_indices)
    #println("edge_endpoint_sum ", edge_endpoint_sum)
    
    num_input_edges = length(edge_indices)
    
    # One new vertex for each input face, one new vertex for each edge
    output_num_vertices = num_vertices + num_faces + num_input_edges
    
    # 1 .. NV           Original input vertices (initially, are overwritten later on)
    # NV+1 .. NV+NF     New face points 
    # NV+NF+1 .. end    New edge points
    output_vertices = Array{Float32}(undef, 3*output_num_vertices)
    
    function face_point_index(fi)
        return num_vertices + fi
    end

    # Copy original input vertex positions
    output_vertices[1:3*num_vertices] = vertices
    
    # Output is always all quads
    # Each input face is split into n quads, where n is the number of vertices in the face
    output_num_quads = sum(loop_total)
    output_loop_start = [1:4:output_num_quads*4;]
    output_loop_total = fill(UInt32(4), output_num_quads)   
    output_loops = Array{UInt32}(undef, 4*output_num_quads)
    
    println("Output: $(output_num_vertices) vertices, $(output_num_quads) quads")   

    #
    # Subdivide
    #
    
    # Add new face vertices: average of existing original face vertices
    for fi = 1:num_faces
    
        sum = Vector{Float32}([0, 0, 0])    
        ls = loop_start[fi]
        nv = loop_total[fi]
        for vi = loops[ls:ls+nv-1]                
            sum += get_vertex(vertices, vi)
        end
        set_vertex(output_vertices, face_point_index(fi), sum / nv)
    end
    
    #println("FV ", face_vertices)
    #println("OV ", output_vertices)
    
    # Add new edge vertices: average of edge endpoints and neighbouring face points
    
    edge_points = Dict{Edge, Vec3}    
    
    for fi = 1:num_faces
    
        #println("face ", fi)

        ls = loop_start[fi]
        nv = loop_total[fi]
        loop = loops[ls:ls+nv-1]
        
        for i = 0:nv-1
            cur = i+1
            next = (i+1) % nv + 1
            
            A = loop[cur]
            B = loop[next]
            
            if A >= B
                # Skip edge as we already handled it for (B, A) case
                continue
            end
            
            key = (A,B)
            rkey = (B,A)
            
            # XXX we assume a watertight mesh here ;-)
            left = edge_faces[key]
            right = edge_faces[rkey]
            
            edge_point = (                
                get_vertex(output_vertices, face_point_index(left))
                +
                get_vertex(output_vertices, face_point_index(right))
                +
                edge_endpoint_sum[key]
            ) / 4
            
            #println(edge_point)
            
            ei = edge_indices[key]
            set_vertex(output_vertices, ei, edge_point)
        end
        
    end
    
    # Move original input vertices to new positions
    
    #println("EV ", edge_vertices)
    #println("OV ", output_vertices)
    
    #println("returning:")
    #println(output_vertices)
    
    return output_vertices, output_loop_start, output_loop_total, output_loops
end
