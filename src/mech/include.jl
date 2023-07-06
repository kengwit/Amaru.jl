# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export elem_config_dofs, elem_init, elem_stiffness, elem_mass, update_elem!, elem_vals
export set_state

# include("mech-properties.jl")

include("elem/mech.jl")
include("elem/distributed.jl")

# Elements
include("elem/mech-solid.jl")
#include("elem/in-mech-solid.jl")
include("elem/mech-rod.jl")
include("elem/mech-embrod.jl")
include("elem/mech-beam.jl")
include("elem/mech-joint.jl")
include("elem/mech-rsjoint.jl")
include("elem/mech-tipjoint.jl")
include("elem/mech-plate-mzc-quad4.jl")
include("elem/mech-plate-rm-quad4.jl")
include("elem/mech-plate-rm-quad8.jl")
include("elem/mech-shell-quad4.jl")
include("elem/mech-shell-degenerated.jl")
include("elem/mech-cook-shell.jl")
include("elem/mech-shell.jl")


# Models for bulk elements
include("mat/linear-elastic.jl")
# include("mat/elastic-solid.jl")
include("mat/dp-solid.jl")
include("mat/vm-solid.jl")
include("mat/mazars-solid.jl")
include("mat/sc-solid.jl")
include("mat/compressible-bulk.jl")
# include("mat/compressiveconcrete-solid.jl")
include("mat/damageconcrete-solid.jl")

# Spring, dumper, lumped mass
include("elem/mech-lumpedmass.jl")
include("mat/lumpedmass.jl")
include("elem/mech-spring.jl")
include("mat/elastic-spring.jl")

# Models for truss elements
# include("mat/elastic-rod.jl")
include("mat/pp-rod.jl")

# Models for beams
# include("mat/elastic-beam.jl")

# Models for plates
include("mat/elastic-plateMZC.jl")
include("mat/elastic-plateRM.jl")
include("mat/elastic-plateRM8node.jl")

# Models for shels
include("mat/elastic-shell-quad4.jl")
include("mat/elastic-shell-degenerated.jl")
include("mat/elastic-cook-shell.jl")
# include("mat/elastic-shell.jl")

# Models for joint elements
include("mat/elastic-joint.jl")
include("mat/mc-joint.jl")
include("mat/p-joint.jl")
include("mat/mmc-joint.jl")
include("mat/tc-joint.jl")
include("mat/tcf-joint.jl")

# Models for 1D joint elements
include("mat/elastic-rsjoint.jl")
include("mat/ceb-rsjoint.jl")
include("mat/cyclic-rsjoint.jl")
include("mat/tipjoint.jl")
include("mat/elastic-tipjoint.jl")

# Stress-update integrator
include("mat/integrator.jl")

# Solvers
include("mech-solver.jl")
include("dyn-solver.jl")
include("modal-solver.jl")

export mech_solve!, solve!

# function reset_displacements(model::Model)
#     for n in model.nodes
#         for dof in n.dofs
#             for key in (:ux, :uy: :uz)
#                 haskey!(dof.vals, key) && (dof.vals[key]=0.0)
#             end
#         end
#     end
# end