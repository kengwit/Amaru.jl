# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export MechModalAnalysis

MechModalAnalysis_params = [
    FunInfo(:DynAnalysis, "Dynamic analysis"),
    ArgInfo(:model, "Finite element model"),
]
@doc docstring(MechModalAnalysis_params) MechModalAnalysis


mutable struct MechModalAnalysis<:StaticAnalysis
    model ::FEModel
    ctx   ::MechContext
    sctx  ::SolverContext

    stages  ::Array{Stage}
    loggers ::Array{AbstractLogger,1}
    monitors::Array{AbstractMonitor,1}

    function MechModalAnalysis(model::FEModel; outdir=".", outkey="out")
        this = new(model, model.ctx)
        this.stages = []
        this.loggers = []
        this.monitors = []  
        this.sctx = SolverContext()
        this.sctx.outdir = outdir
        this.sctx.outkey = outkey

        model.ctx.thickness = model.thickness
        if model.ctx.stressmodel==:none
            if model.ctx.ndim==2
                model.ctx.stressmodel = :planestrain
            else
                model.ctx.stressmodel = :d3
            end
        end

        return this
    end
end


mech_modal_solver_params = [
    FunInfo( :mech_modal_solver!, "Finds the frequencies and vibration modes of a mechanical system."),
    ArgInfo( :model, "FEModel object"),
    ArgInfo( :stage, "Stage object"),
    KwArgInfo( :nmodes, "Number of modes to be calculated", 5),
    KwArgInfo( :rayleigh, "Flag to use Rayleigh-Ritz method for damping", false),
    KwArgInfo( :quiet, "Flag to set silent mode", false),
]
@doc docstring(mech_modal_solver_params) solve!(::MechModalAnalysis; args...)

function solve!(ana::MechModalAnalysis; args...)
    args = checkargs(args, mech_modal_solver_params)
    if !args.quiet
        printstyled("Solver for mechanical modal analyses", "\n", bold=true, color=:cyan)
        println("  stress model: ", ana.ctx.stressmodel)
    end

    status = stage_iterator!(mech_modal_solver!, ana; args...)
    return status
end


function mech_modal_solver!(ana::MechModalAnalysis, stage::Stage; kwargs...)
    args = NamedTuple(kwargs)
    # args = checkargs(kwargs, mech_modal_solver_params)
    nmodes = args.nmodes
    rayleigh = args.rayleigh
    quiet = args.quiet 

    model = ana.model
    ctx = model.ctx
    sctx = ana.sctx

    quiet || println(sctx.log, "Modal analysis for mechanical systems")

    stressmodel = ctx.stressmodel
    ctx.ndim==3 && @check stressmodel==:d3

    # todo: check there are not force boundary conditions

    # get only bulk elements
    model = FEModel(model.elems.bulks)

    # check density
    for elem in model.elems
        elem.props.ρ==0 && error("mech_modal_solver: density should not be zero")
    end

    # get dofs organized according to boundary conditions
    dofs, nu    = configure_dofs!(model, stage.bcs)

    ndofs       = length(dofs)
    model.ndofs = length(dofs)

    if !quiet
        println(sctx.log, "unknown dofs: $nu")
        println(sctx.info, "unknown dofs: $nu")
    end

    # setup quantities at dofs
    for dof in dofs
        dof.vals[dof.name]    = 0.0
        dof.vals[dof.natname] = 0.0
    end

    K11 = mount_K(model.elems, ndofs)[1:nu, 1:nu]
    M11 = mount_M(model.elems, ndofs)[1:nu, 1:nu]

    m11 = zeros(nu) #Vetor of inverse matrix mass
    for i in 1:size(M11,2)
        m11[i] = 1.0/M11[i,i]
    end

    # inverse of the lumped matrix in vector form
    P = m11.*K11

    # m11 = inv(Matrix(M11))
    # P = m11*K11

    # eingenvalues and eingenvectors
    # Eig = eigs(P, nev=nmodes, which=:SR, tol=1e-6, maxiter=600, check=1) # SR: smallest real part
    # Eig = eigs(P, nev=nmodes, which=:SM) # SM: smallest magnitude
    Eig = eigs(P, nev=nmodes, which=:LM) # LM: largest magnitude
    w0  = Eig[1] # frequencies
    wi  = copy(w0)

    # select possible vals
    filter = [ i for i in eachindex(wi) if isreal(wi[i]) && real(wi[i])>0 ]
    filter = filter[ unique(i -> wi[i], filter) ]  # todo: do not remove eingenvalues
    perm   = sortperm(real(wi[filter]))[1:nmodes]
    filter = filter[perm]

    wi = wi[filter] # sorted
    v  = Eig[2][:, filter]

    w = wi.^0.5  # true frequencies

    update_output_data!(model)
    save(model, joinpath(sctx.outdir, "$(sctx.outkey)-0.vtu"), quiet=true)

    sctx.inc = 1
    sctx.ΔT  = 1.0
    
    # save modes
    for i in 1:nmodes
        U = v[:,i] # modal displacements
        
        for (k,dof) in enumerate(dofs[1:nu])
            dof.vals[dof.name] = U[k]
        end
        sctx.T = i/nmodes
        sctx.out = i
        update_output_data!(model)
        save(model, joinpath(sctx.outdir, "$(sctx.outkey)-$i.vtu"), quiet=true)
    end

    # reset displacement values
    for dof in dofs
        dof.vals[dof.name] = 0.0
    end

    # show modal frequencies
    if !quiet
        println(sctx.log, "modal frequencies:")
        for i in 1:nmodes
            println(sctx.log, "ω$i = ", abs(w[i]))
        end
    end

    # show("Modal Frequencies rad/s")
    # @show w
    #show("Modal Shapes rad/s")
    #@show v

    if rayleigh
        #Rayleigh-Ritz method for Damping

        println("What is the damping relationship 1 (xi1 = c/c_c)?")
        xi1 = parse(Float64,chomp(readline()))
        println("What is the damping relationship 2 (xi2 = c/c_c)?")
        xi2 = parse(Float64,chomp(readline()))


        #Interacting with the user for select the correct frequêncies based on modal deformated

        println("See the vtk files of the modal deformated and decide")
        print("What is the first frequency that you want?")
        w1 = w[parse(Int,chomp(readline()))]
        print("What is the second frequency that you want?")
        w2 = w[parse(Int,chomp(readline()))]

        alpha = 2*(w1^2*w2*xi2 - w1*w2^2*xi1) / (w1^2-w2^2)
        beta  = 2*(w1*xi1 - w2*xi2)/(w1^2 - w2^2)

        info("Rayleigh alpha: ", alpha)
        info("Rayleigh beta:", beta)
    end

    return success()

end


function modsolvex!(model::FEModel, bcs::AbstractArray; nmodes::Int=5, rayleigh=false, save=true, quiet=false)

    quiet || printstyled("FEM modal analysis:\n", bold=true, color=:cyan)

    # Get dofs organized according to boundary conditions
    dofs, nu = configure_dofs!(model, bcs)

    ndofs = length(dofs)
    model.ndofs = length(dofs)
    !quiet && println("  unknown dofs: $nu")

    K = mount_Kf(model, ndofs)
    M = mount_Mf(model, ndofs)

    if nu>0
        K11 = K[1:nu, 1:nu]
        M11 = M[1:nu, 1:nu]
    end

    #Delete columns and rows that corresponding at bars and joint elements

    nodesbars=getnodes(model.elems.lines) #nodes of bars

    idsd = Array{Int64,1}() #idsd ids for delete

    for node in nodesbars
        for dof in node.dofs
            push!(idsd,dof.eq_id)
        end
    end
    idsd = unique(idsd)
    sort!(idsd)
    nidsd = length(idsd)

    for i in 1:nidsd
       M11=M11[1:size(M11,1)     .!= idsd[nidsd+1-i,1],:];
       M11=M11[:,1:size(M11,2) .!= idsd[nidsd+1-i,1]];
       K11=K11[1:size(K11,1)     .!= idsd[nidsd+1-i,1],:];
       K11=K11[:,1:size(K11,2) .!= idsd[nidsd+1-i,1]];
    end

    m11 = zeros(size(M11,2)) #Vetor of inverse matrix mass

    for i in 1:size(M11,2)
        m11[i] = 1/M11[i,i]
    end

    # Inverse of the lumped matrix in vector form
    #m11 = inv.(sum(M11, 2))
    P = m11.*K11


    #Eingenvalues and Eingenvectors

    nevn=size(P,2)-2 #eigvals number

    #using Arpack

    Eig=eigs(P, nev=20, which=:SM)

    #using LinearAlgebra
    w0 = Eig[1]
    #w0 = eigvals(P)
    wi = copy(w0)

    #Select logical and possible vals

    wi=real(wi[isreal.(wi)]) #delete imaginarian numbers
    wi=unique(wi) #all vals diferents
    wi=wi[wi[1:size(wi)[1]] .>0] # delete zero and negative vals
    wi=sort!(wi) # sort the vector

    w = Array{Float64,1}()

    for i in 1:nmodes
        push!(w,wi[i])
    end

    v = Array{Float64,2}(undef,size(P,2),nmodes)

    for i in 1:nmodes
        col = findfirst(isequal(w[i]),w0)
        col = col[1]
        #v[:,i] = eigvecs(P)[:,col]
        v[:,i] = Eig[2][:,col]
    end

    w = w.^0.5

    if save

        #Modals Deformed

        nodessolids = getnodes(model.elems.solids) #nodes of solids

        idss = Array{Int64,1}() #idss ids of dof solids

        for node in nodessolids
            for dof in node.dofs
                push!(idss,dof.eq_id)
            end
        end
        idss = unique(idss)
        sort!(idss)
        nidss = length(idss)
        idefmod = 1

        for j in 1:nmodes

            Umod = zeros(ndofs)

            for i in 1:length(v[:,j])
                Umod[idss[i]] = v[i,j]
            end

            for (k,dof) in enumerate(dofs)
                dof.vals[dof.name] = Umod[k]
            end

            save(model, model.filekey * "-defmod$idefmod.vtk") # saves current domain state for modal deformated
            idefmod += 1
        end

    end


    # reset displacement values
    for (k,dof) in enumerate(dofs)
        dof.vals[dof.name] = 0.0
    end

    show("Modal Frequencies rad/s")

    if rayleigh


        #Rayleigh-Ritz method for Damping

        println("What is the damping relationship 1 (xi1 = c/c_c)?")
        xi1 = parse(Float64,chomp(readline()))
        println("What is the damping relationship 2 (xi2 = c/c_c)?")
        xi2 = parse(Float64,chomp(readline()))


        #Interacting with the user for select the correct frequêncies based on modal deformated

        println("See the vtk files of the modal deformated and decide")
        print("What is the first frequency that you want?")
        w1 = w[parse(Int,chomp(readline()))]
        print("What is the second frequency that you want?")
        w2 = w[parse(Int,chomp(readline()))]

        alpha = 2 * ((w1 ^ 2) * w2 * xi2 - w1 * (w2 ^ 2) * xi1) / ((w1 ^ 2)-(w2 ^ 2))
        beta  = 2 * (w1 * xi1 - w2 * xi2)/((w1 ^ 2) - (w2 ^ 2))

        info("Rayleigh alpha: ", alpha)
        info("Rayleigh beta:", beta)

    end


end