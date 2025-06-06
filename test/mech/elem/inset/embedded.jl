using Amaru
using Test

# Mesh generation
bl  = Block( [0 0 0; 1.0 6.0 1.0], nx=1, ny=5, nz=3, tag="solid")
bl1 = BlockInset( [0.2 0.2 0.2; 0.2 5.8 0.2], curvetype="polyline", embedded=true, tag="embedded")
bl2 = copy(bl1)
move!(bl2, dx=0.6)
bls = [ bl, bl1, bl2 ]

msh = Mesh(bls)

# FEM analysis
mats = [
        "solid" => MechSolid => LinearElastic => (E=1.e4, nu=0.25),
        "embedded" => MechBar => VonMises => (E=1.e8, fy=500e3, A=0.005),
       ]

ctx = MechContext()
model = FEModel(msh, mats, ctx)
ana = MechAnalysis(model)

bcs = [
       :(y==0 && z==0) => NodeBC(ux=0, uy=0, uz=0),
       :(y==6 && z==0) => NodeBC(ux=0, uy=0, uz=0),
       :(z==1) => SurfaceBC(tz=-1000),
      ]
addstage!(ana, bcs, nincs=20)

solve!(ana, autoinc=true)