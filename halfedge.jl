mutable struct HalfEdge
    source  ::UInt32        # Vertex index
    target  ::UInt32        # Vertex index
    face    ::UInt32        # Face index
    
    index   ::UInt32        # Should be same value for sibling edge

    next    ::HalfEdge
    prev    ::HalfEdge
    
    # Can be nothing for a boundary edge
    sibling ::Union{HalfEdge, Nothing}
    
    HalfEdge(s, t, f, i) = new(s, t, f, i)
end

Base.show(io::IO, he::HalfEdge) = print(io, 
    "HalfEdge([", he.index, "] ", he.source, " -> ", he.target, ", f:", he.face, ", ", 
    he.sibling != nothing ? "s" : "!s", 
    ")")

const VertexPair = Tuple{UInt32, UInt32}

function build(vertices, loop_start, loop_total, loops)
    
    # Temporary index
    half_edges = Dict{VertexPair, HalfEdge}()       
    
    vertex_start_edges = Dict{UInt32, HalfEdge}()
    face_start_edges = Dict{UInt32, HalfEdge}()        
    
    num_vertices = trunc(UInt32, length(vertices) / 3)
    num_faces = length(loop_start)
    
    # One of the two edges of a polygon edge
    edges = HalfEdge[]
    num_edges = 0      
    
    for fi = 1:num_faces
    
        ls = loop_start[fi]
        nv = loop_total[fi]
        loop = loops[ls:ls+nv-1]
        
        first_he = nothing
        last_halfedge = nothing
        
        for i = 0:nv-1
            cur = i+1
            next = (i+1) % nv + 1
            
            A = loop[cur]
            B = loop[next]

            key = (A,B)
            rkey = (B,A)
            
            if haskey(half_edges, rkey)
                he2 = half_edges[rkey]
                he = HalfEdge(A, B, fi, he2.index)
                he2.sibling = he
                he.sibling = he2
            else
                num_edges += 1
                he = HalfEdge(A, B, fi, num_edges)
                he.sibling = nothing
                push!(edges, he)
            end
            
            @assert !haskey(half_edges, key)
            half_edges[key] = he              
            
            if i == 0
                face_start_edges[fi] = he
                first_he = he
            end
            
            if !haskey(vertex_start_edges, A)
                vertex_start_edges[A] = he
            end
            
            if last_halfedge != nothing
                last_halfedge.next = he
                he.prev = last_halfedge
            end

            last_halfedge = he
        end
        
        last_halfedge.next = first_he
        first_he.prev = last_halfedge
    
    end
    
    @assert length(vertex_start_edges) == num_vertices
    
    return num_vertices, num_faces, num_edges, vertex_start_edges, face_start_edges, edges
    
end

