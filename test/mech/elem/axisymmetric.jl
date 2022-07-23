using Amaru
using Test

for shape in (TRI3, TRI6, QUAD4, QUAD8)
    # Axisymmetric
    printstyled("$(shape.name)\n", color=:cyan)
    printstyled("axisymmetric\n", color=:cyan)

    bl = Block( [0 0; 1 1], nx=4, ny=4, cellshape=shape, tag="solids")
    mesh = Mesh(bl, printlog=false)

    materials = [
        "solids" => ElasticSolid(E=100.0, nu=0.2)
    ]

    dom = Domain(mesh, materials, modeltype="axisymmetric", printlog=false)

    bcs = [
           :(x==0) => SurfaceBC(ux=0),
           :(y==0) => SurfaceBC(uy=0),
           :(y==1) => SurfaceBC(ty=-10),
           #"solids" => SurfaceBC(ty=-10),
    ]

    solve!(dom, bcs, nincs=1, printlog=false, nouts=0).success

    sample_node = dom.nodes[:(x==1 && y==1)][1]
    uxr = sample_node.dofs[:ux].vals[:ux]
    uyr = sample_node.dofs[:uy].vals[:uy]
    println( get_data(dom.nodes[:(x==1 && y==1)][1]) )

    # 3D
    printstyled("3d version", color=:cyan); println()

    mesh = revolve(mesh, n=12)
    dom = Domain(mesh, materials, modeltype="3d", printlog=false)

    bcs = [
           :(x==0 && y==0) => NodeBC(ux=0, uy=0),
           :(y==0) => SurfaceBC(uy=0),
           :(y==1) => SurfaceBC(ty=-10),
           #"solids" => SurfaceBC(ty=-10),
    ]

    solve!(dom, bcs, nincs=1, printlog=false, nouts=0).success
    sample_node = dom.nodes[:(x==1 && y==1)][1]
    ux = sample_node.dofs[:ux].vals[:ux]
    uy = sample_node.dofs[:uy].vals[:uy]

    println( get_data(dom.nodes[:(x==1 && y==1)][1]) )

    # Verification
    @test [uxr, uyr] ≈ [ux, uy] atol=1e-3

end
