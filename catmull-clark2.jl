include("halfedge.jl")

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
    
    num_vertices, num_faces, num_edges, vertex_start_edges, face_start_edges, polygon_edges = build(vertices, loop_start, loop_total, loops)
    
    println("Input: $(num_vertices) vertices, $(num_faces) polygons, $(num_edges) polygon edges")
        
    # One new vertex for each input face, one new vertex for each edge
    output_num_vertices = num_vertices + num_faces + num_edges
    
    # 1 .. NV           Original input vertices (initially, are overwritten later on)
    # NV+1 .. NV+NF     New face points 
    # NV+NF+1 .. end    New edge points
    output_vertices = Array{Float32}(undef, 3*output_num_vertices)
    
    function face_point_index(fi)
        return num_vertices + fi
    end

    function edge_point_index(ei)
        return num_vertices + num_faces + ei
    end

    # Copy original input vertex positions, to be modified later on
    output_vertices[1:3*num_vertices] = vertices
    
    # Output is always all quads, as each input face is split into n quads, 
    # where n is the number of vertices in the face
    output_num_quads = sum(loop_total)
    output_loop_start = [1:4:output_num_quads*4;]
    output_loop_total = fill(UInt32(4), output_num_quads)   
    output_loops = Array{UInt32}(undef, 4*output_num_quads)
    
    println("Output: $(output_num_vertices) vertices, $(output_num_quads) quads")   

    #
    # Subdivide
    #
    
    # Add new face points: average of existing original face vertices
    for fi = 1:num_faces
                
        sum = Vector{Float32}([0, 0, 0])
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
        @assert he.sibling != nothing
        he2 = he.sibling
        
        left = he.face
        right = he2.face
        
        edge_point = (                
            get_vertex(output_vertices, face_point_index(left))
            +
            get_vertex(output_vertices, face_point_index(right))
            +
            get_vertex(output_vertices, he.source)
            +
            get_vertex(output_vertices, he.target)
        ) / 4
        
        set_vertex(output_vertices, edge_point_index(ei), edge_point)
    end

    # Move original input vertices to new positions
    
    #println("EV ", edge_vertices)
    #println("OV ", output_vertices)
    
    #println("returning:")
    #println(output_vertices)
    
    return output_vertices, output_loop_start, output_loop_total, output_loops
end
