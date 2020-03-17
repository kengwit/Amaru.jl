# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru


mutable struct ThermoSolid<:Thermomechanical
    id    ::Int
    shape ::ShapeType
    cell  ::Cell
    nodes ::Array{Node,1}
    ips   ::Array{Ip,1}
    tag   ::String
    mat   ::Material
    active::Bool
    linked_elems::Array{Element,1}
    env::ModelEnv

    function ThermoSolid();
        return new()
    end
end

matching_shape_family(::Type{ThermoSolid}) = SOLID_SHAPE

function elem_config_dofs(elem::ThermoSolid)
    for node in elem.nodes
        add_dof(node, :ut, :ft)
    end
end

function elem_init(elem::ThermoSolid)
    nothing
end


function distributed_bc(elem::ThermoSolid, facet::Union{Facet,Nothing}, key::Symbol, val::Union{Real,Symbol,Expr})
    ndim  = elem.env.ndim

    # Check bcs
    (key == :qt) || error("distributed_bc: boundary condition $key is not applicable in a ThermoSolid element")

    target = facet!=nothing ? facet : elem
    nodes  = target.nodes
    nnodes = length(nodes)
    t      = elem.env.t

    # Force boundary condition
    nnodes = length(nodes)

    # Calculate the target coordinates matrix
    C = nodes_coords(nodes, ndim)

    # Vector with values to apply
    QQ = zeros(ndim)

    # Calculate the nodal values
    F     = zeros(nnodes, ndim)
    shape = target.shape
    ips   = get_ip_coords(shape)

    for i=1:size(ips,1)
        R = vec(ips[i,:])
        w = R[end]
        N = shape.func(R)
        D = shape.deriv(R)
        J = D*C
        nJ = norm2(J)
        X = C'*N
        x, y, z = X
        vip = eval_arith_expr(val, t=t, x=x, y=y, z=z)
        F += N*(vip*nJ*w) # F is a vector
    end

    # generate a map
    map  = [ node.dofdict[:ut].eq_id for node in target.nodes ]

    return F, map
end


function elem_conductivity_matrix(elem::ThermoSolid)
    ndim   = elem.env.ndim
    θ0     = elem.env.T0 + 273.15
    nnodes = length(elem.nodes)
    C      = elem_coords(elem)
    H      = zeros(nnodes, nnodes)
    Bt     = zeros(ndim, nnodes)
    KBt    = zeros(ndim, nnodes)

    J    = Array{Float64}(undef, ndim, ndim)
    dNdX = Array{Float64}(undef, ndim, nnodes)

    for ip in elem.ips

        N    = elem.shape.func(ip.R)
        dNdR = elem.shape.deriv(ip.R)
        @gemm J  = dNdR*C
        @gemm Bt = inv(J)*dNdR
        detJ = det(J)
        detJ > 0.0 || error("Negative jacobian determinant in cell $(elem.id)")

        # compute H
        K = calcK(elem.mat, ip.data)
        coef = detJ*ip.w/θ0
        @gemm KBt = K*Bt
        @gemm H -= coef*Bt'*KBt
    end

    # map
    map = [ node.dofdict[:ut].eq_id for node in elem.nodes ]

    return H, map, map
end


function elem_mass_matrix(elem::ThermoSolid)
    ndim   = elem.env.ndim
    θ0     = elem.env.T0 + 273.15
    nnodes = length(elem.nodes)
    C = elem_coords(elem)
    M = zeros(nnodes, nnodes)
    J  = Array{Float64}(undef, ndim, ndim)

    for ip in elem.ips
        N    = elem.shape.func(ip.R)
        dNdR = elem.shape.deriv(ip.R)
        @gemm J = dNdR*C
        detJ = det(J)
        detJ > 0.0 || error("Negative jacobian determinant in cell $(elem.id)")

        # compute Cuu
        coef = elem.mat.ρ*elem.mat.cv*detJ*ip.w/θ0
        M  -= coef*N*N'
    end

    # map
    map = [  node.dofdict[:ut].eq_id for node in elem.nodes  ]

    return M, map, map
end


#=
function elem_RHS_vector(elem::ThermoSolid)
    ndim   = elem.env.ndim
    nnodes = length(elem.nodes)
    C      = elem_coords(elem)
    Q      = zeros(nnodes) # energy flux
    Bt     = zeros(ndim, nnodes)
    KZ     = zeros(ndim)

    J      = Array{Float64}(undef, ndim, ndim)
    dNdX   = Array{Float64}(undef, ndim, nnodes)
    Z      = zeros(ndim) # hydrostatic gradient
    Z[end] = 1.0

    for ip in elem.ips

        N    = elem.shape.func(ip.R)
        dNdR = elem.shape.deriv(ip.R)
        @gemm J  = dNdR*C
        @gemm Bt = inv(J)*dNdR
        detJ = det(J)
        detJ > 0.0 || error("Negative jacobian determinant in cell $(elem.id)")

        # compute Q
        K = calcK(elem.mat, ip.data)
        coef = detJ*ip.w
        @gemv KZ = K*Z
        @gemm Q += coef*Bt'*KZ
    end

    # map
    map = [  node.dofdict[:ut].eq_id for node in elem.nodes  ]

    return Q, map
end
=#


function elem_update!(elem::ThermoSolid, DU::Array{Float64,1}, DF::Array{Float64,1}, Δt::Float64)
    ndim   = elem.env.ndim
    θ0     = elem.env.T0 + 273.15
    nnodes = length(elem.nodes)

    map_t  = [ node.dofdict[:ut].eq_id for node in elem.nodes ]

    C   = elem_coords(elem)

    dUt = DU[map_t] # nodal temperature increments
    Ut  = [ node.dofdict[:ut].vals[:ut] for node in elem.nodes ]
    Ut += dUt # nodal temperature at step n+1

    dF  = zeros(nnodes*ndim)
    dFt = zeros(nnodes)
    Bt  = zeros(ndim, nnodes)

    DB = Array{Float64}(undef, 6, nnodes*ndim)
    J  = Array{Float64}(undef, ndim, ndim)
    dNdX = Array{Float64}(undef, ndim, nnodes)

    for ip in elem.ips

        # compute Bu matrix
        N    = elem.shape.func(ip.R)
        dNdR = elem.shape.deriv(ip.R)
        @gemm J = dNdR*C
        detJ = det(J)
        detJ > 0.0 || error("Negative jacobian determinant in cell $(cell.id)")

        Bt = dNdX
        G  = Bt*Ut/θ0 # flow gradient

        Δut = N'*dUt # interpolation to the integ. point

        QQ = update_state!(elem.mat, ip.data, Δut, G, Δt)

        coef = Δt*detJ*ip.w
        @gemv dFt += coef*Bt'*QQ
    end

    DF[map_t] += dFt
end
