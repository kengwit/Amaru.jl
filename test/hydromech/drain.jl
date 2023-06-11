using Amaru

# Mesh generation
#bl  = Block( [0 0 0; 2.0 2.0 1.0], nx=2, ny=2, nz=1, cellshape=HEX8, tag="solids")
bl  = Block( [0 0 0; 2.0 2.0 1.0], nx=4, ny=4, nz=2, cellshape=HEX20, tag="solids")
bl1 = BlockInset( [1.0 1.0 1.0; 0.0 0.0 0.0], curvetype="polyline", tag="drains", jointtag="joints")
bl2 = BlockInset( [1.0 1.0 1.0; 2.0 2.0 0.0], curvetype="polyline", tag="drains", jointtag="joints")
bls = [bl, bl1, bl2]

mesh = Mesh(bls)

gw = 10.0     # water specific weight
A  = 0.01
k  = 1e-10 
kb = 1 
kj = 10 
Q  = 1       # volume em metro cubico

# FEM analysis
mats = [
    "solids" => LinSeep(k=k, gammaw=gw, S=0.0),
    "joints" => Joint1DLinSeep(k=kj, gammaw=gw, A=A),
    "drains" => LinDrainPipe(k=kb, gammaw=gw, A=A),
]

model = FEModel(mesh, mats, gammaw=10)

# Stage 1: pore-pressure stabilization
bcs = [
       :(z==1.0) => NodeBC(uw=0),
      ]
addstage!(model, bcs, tspan=100, nincs=2, nouts=2)
hm_solve!(model, tol=1e-2)

tag!(model.elems.solids.nodes[:(x==1.0 && y==1.0 && z==1.0)], "input")

# Stage 2: volume application
bcs = [
       :(x==0.0 && y==0.0 && z==0.0) => NodeBC(uw=0),
       :(x==2.0 && y==2.0 && z==0.0) => NodeBC(uw=0),
       "input" => NodeBC(fw=:($Q*t/100)),
      ]
addstage!(model, bcs, tspan=100, nincs=2, nouts=2)
hm_solve!(model, tol=1e-2)
