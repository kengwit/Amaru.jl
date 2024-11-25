using Amaru

# # 2D beam

# coord = [ 0 0; 1 0; 0.5 0.5]
# n     = 2
# bl    = Block(coord, nx=n, cellshape = LIN3, tag="beam")
# msh   = Mesh(bl, ndim=2)

# mats  = [ "beam" => MechBeam => ElasticBeam => (E=1e4, nu=0, thy=0.1, thz=0.1) ]

# ana = MechAnalysis()
# model = FEModel(msh, mats, ana)

# monitors = [
#     :(x==0) => NodeMonitor(:(mz))
#     :(x==0) => NodeMonitor(:(fx))
#     :(x==0) => NodeMonitor(:(fy))
#     :(x==1) => NodeMonitor(:(uy))
# ]
# setmonitors!(model, monitors)

# bcs =
# [
#    :(x==0) => NodeBC(rz=0, ux=0, uy=0),
#    :(x==1) => NodeBC(fx=1, fy=2),
# ]
# addstage!(model, bcs)
# solve!(model)


# 3D beam

coord = [ 0 0 0; 1 0 0; 0.5 0 0.5]
n     = 2
bl    = Block(coord, nx=n, cellshape = LIN3, tag="beam")
msh   = Mesh(bl, ndim=3)

mats  = [ "beam" => MechBeam => LinearElastic => (E=1e4, nu=0, thy=0.1, thz=0.1) ]
# mats  = [ "beam" => MechBeam => ElasticBeam => (E=1e4, nu=0, A=0.01) ]

ctx = MechContext()
model = FEModel(msh, mats, ctx)
ana = MechAnalysis(model)

# changequadrature!(model.elems, 3)

monitors = [
    :(x==0) => NodeMonitor(:(my))
    :(x==0) => NodeMonitor(:(fx))
    :(x==0) => NodeMonitor(:(fz))
    :(x==1) => NodeMonitor(:(uz))
]
setmonitors!(ana, monitors)

bcs =
[
   :(x==0) => NodeBC(rx=0, ry=0, rz=0, ux=0, uy=0, uz=0),
   :(x==1) => NodeBC(fx=1, fz=2),
]
addstage!(ana, bcs)
solve!(ana, quiet=false)