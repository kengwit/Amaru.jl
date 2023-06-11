using Amaru

# Finite element entities
bl  = Block( [0 0; 1 1], nx=4, ny=4, cellshape=QUAD9, tag="solids")
msh = Mesh(bl)

mats = [ "solids" =>  ElasticSolid(E=100.0, nu=0.2) ]
model = FEModel(msh, mats)

loggers = [
        :(x==1 && y==1) => NodeLogger("node.dat"),
        :(y==1)         => NodeGroupLogger("nodes.dat"),
       ]
setloggers!(model, loggers)


bcs = [
        :(y==0) => NodeBC(ux=0, uy=0),
        :(y==1) => SurfaceBC(ty=2),
      ]

addstage!(model, bcs, nincs=3)
solve!(model)

table = DataTable("node.dat")
book  = DataBook("nodes.dat")

rm("node.dat")
rm("nodes.dat")

println(bl)
println(msh)
println(mats)
println(loggers[1])
println(loggers)
println(bcs[1])
println(bcs)
println(model.nodes[1].dofs[1])
println(model.nodes[1].dofs)
println(model.nodes[1])
println(model.nodes)
println(model.elems[1])
println(model.elems)
println(model)

println(table)
println(book)
