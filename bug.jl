vertices = Array{Float32}([-1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0])
loop_start = Array{UInt32}([0x00000001, 0x00000005, 0x00000009, 0x0000000d, 0x00000011, 0x00000015])
loop_total = Array{UInt32}([0x00000004, 0x00000004, 0x00000004, 0x00000004, 0x00000004, 0x00000004])
loops = Array{UInt32}([0x00000001, 0x00000002, 0x00000004, 0x00000003, 0x00000003, 0x00000004, 0x00000008, 0x00000007, 0x00000007, 0x00000008, 0x00000006, 0x00000005, 0x00000005, 0x00000006, 0x00000002, 0x00000001, 0x00000003, 0x00000007, 0x00000005, 0x00000001, 0x00000008, 0x00000004, 0x00000002, 0x00000006])

include("halfedge.jl")

num_vertices, num_faces, num_edges, vertex_start_edges, face_start_edges, edges = build(vertices, loop_start, loop_total, loops)

println(length(vertex_start_edges), " v, ", length(face_start_edges), " f, ", num_edges, " e")

println(vertex_start_edges)
println(face_start_edges)
println(edges)

for (fi, he) in face_start_edges
    println("Face ", fi, ":")
    start = he
    while true
        println(he.source)
        he = he.next
        if he == start
            break
        end
    end
end
