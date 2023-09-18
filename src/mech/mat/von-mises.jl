export VonMises


"""
    VonMises

A type for linear elastic materials with Von Mises failure criterion.

# Fields

$(TYPEDFIELDS)
"""
mutable struct VonMises<:Material
    "Young modulus"
    E ::Float64
    "Poisson ratio"
    ν ::Float64
    "Yielding stress"
    σy::Float64
    "Hardening parameter"
    H ::Float64
    "Density"
    ρ::Float64

    function VonMises(prms::Dict{Symbol,Float64})
        return VonMises(;prms...)
    end

    @doc """
        $(SIGNATURES)

    Creates an `VonMises` material type

    # Arguments
    - `E`: Young modulus
    - `nu`: Poisson ratio
    - `fy`: Yielding stress
    - `H`: Hardening parameter
    """
    function VonMises(; args...)
        args = checkargs(args, arg_rules(VonMises))       

        return new(args.E, args.nu, args.fy, args.H, args.rho)
    end
end

arg_rules(::Type{VonMises}) = 
[
    @arginfo E E>0.0 "Young modulus"
    @arginfo nu=0.0 0.0<=nu<0.5 "Poisson ratio"
    @arginfo fy fy>=0.0 "Yield stress"
    @arginfo H=0.0 H>=0.0 "Hardening modulus"
    @arginfo rho=0.0 rho>=0.0 "Density"
]


mutable struct VonMisesState<:IpState
    env::ModelEnv
    σ::Vec6
    ε::Vec6
    εpa::Float64
    Δλ::Float64
    function VonMisesState(env::ModelEnv)
        this = new(env)
        this.σ   = zeros(Vec6)
        this.ε   = zeros(Vec6)
        this.εpa = 0.0
        this.Δλ  = 0.0
        this
    end
end

mutable struct VonMisesPlaneStressState<:IpState
    env::ModelEnv
    σ::Vec6
    ε::Vec6
    εpa::Float64
    Δλ::Float64
    function VonMisesPlaneStressState(env::ModelEnv)
        this = new(env)
        this.σ   = zeros(Vec6)
        this.ε   = zeros(Vec6)
        this.εpa = 0.0
        this.Δλ  = 0.0
        this
    end
end

mutable struct VonMisesBeamState<:IpState
    env::ModelEnv
    σ::Vec3
    ε::Vec3
    εpa::Float64
    Δλ::Float64
    function VonMisesBeamState(env::ModelEnv)
        this = new(env)
        this.σ   = zeros(Vec3)
        this.ε   = zeros(Vec3)
        this.εpa = 0.0
        this.Δλ  = 0.0
        this
    end
end

mutable struct VonMisesBarState<:IpState
    env::ModelEnv
    σ::Float64
    ε::Float64
    εpa::Float64
    Δλ::Float64
    function VonMisesBarState(env::ModelEnv)
        this = new(env)
        this.σ   = 0.0
        this.ε   = 0.0
        this.εpa = 0.0
        this.Δλ  = 0.0
        this
    end
end


compat_state_type(::Type{VonMises}, ::Type{MechSolid}, env::ModelEnv) = env.ana.stressmodel=="plane-stress" ? VonMisesPlaneStressState : VonMisesState
compat_state_type(::Type{VonMises}, ::Type{MechShell}, env::ModelEnv) = VonMisesPlaneStressState
compat_state_type(::Type{VonMises}, ::Type{MechBeam}, env::ModelEnv) = VonMisesBeamState
compat_state_type(::Type{VonMises}, ::Type{MechBar}, env::ModelEnv) = VonMisesBarState
compat_state_type(::Type{VonMises}, ::Type{MechEmbBar}, env::ModelEnv) = VonMisesBarState


# VonMises model for 3D and 2D bulk elements (not including plane-stress state)

function yield_func(mat::VonMises, state::VonMisesState, σ::Vec6, εpa::Float64)
    j2d = J2D(σ)
    σy  = mat.σy
    H   = mat.H
    return √(3*j2d) - σy - H*εpa
end


function calcD(mat::VonMises, state::VonMisesState)
    De  = calcDe(mat.E, mat.ν)
    state.Δλ==0.0 && return De

    j2d = J2D(state.σ)
    @assert j2d>0

    s     = dev(state.σ)
    dfdσ  = √1.5*s/norm(s)
    dfdεp = -mat.H

    return De - De*dfdσ*dfdσ'*De / (dfdσ'*De*dfdσ - √1.5*dfdεp)

end


function update_state!(mat::VonMises, state::VonMisesState, Δε::Array{Float64,1})
    σini = state.σ
    De   = calcDe(mat.E, mat.ν)
    σtr  = state.σ + De*Δε
    ftr  = yield_func(mat, state, σtr, state.εpa)
    tol  = 1e-8

    if ftr<tol
        # elastic
        state.Δλ = 0.0
        state.σ  = σtr
    else
        # plastic
        E, ν  = mat.E, mat.ν
        G     = E/(2*(1+ν))
        j2dtr = J2D(σtr)

        √j2dtr - state.Δλ*√3*G >= 0.0 || return state.σ, failure("VonMisses: Negarive value for √J2D")
        state.Δλ = ftr/(3*G + √1.5*mat.H)

        s = (1 - √3*G*state.Δλ/√j2dtr)*dev(σtr)
        state.σ = σtr - √6*G*state.Δλ*s/norm(s)
        state.εpa += state.Δλ
    end

    state.ε += Δε
    Δσ     = state.σ - σini
    return Δσ, success()
end


function ip_state_vals(mat::VonMises, state::VonMisesState)
    σ, ε  = state.σ, state.ε
    j1    = tr(σ)
    srj2d = √J2D(σ)

    D = stress_strain_dict(σ, ε, state.env.ana.stressmodel)
    D[:epa]   = state.εpa
    D[:j1]    = j1
    D[:srj2d] = srj2d

    return D
end


# VonMises model for 2D bulk elements under plane-stress state includind shell elements


function yield_func(mat::VonMises, state::VonMisesPlaneStressState, σ::AbstractArray, εpa::Float64)
    # f = 1/2 σ*Psd*σ - 1/3 (fy + H εp)^2
    # f = J2D - 1/3 (fy + H εp)^2

    j2d = J2D(σ)

    σy  = mat.σy
    H   = mat.H
    return j2d - 1/3*(σy + H*εpa)^2
end


function calcD(mat::VonMises, state::VonMisesPlaneStressState)
    De  = calcDe(mat.E, mat.ν, "plane-stress")
    state.Δλ==0.0 && return De
    σ = state.σ

    s     = SVector( 2/3*σ[1] - 1/3*σ[2], 2/3*σ[2] - 1/3*σ[1], -1/3*σ[1]-1/3*σ[2], σ[4], σ[5], σ[6] )
    dfdσ  = s
    dfdεp = -2/3*mat.H*(mat.σy + mat.H*state.εpa)

    return De - De*dfdσ*dfdσ'*De / (dfdσ'*De*dfdσ - norm(s)*dfdεp)

end


function update_state!(mat::VonMises, state::VonMisesPlaneStressState, Δε::Array{Float64,1})
    σini = state.σ
    De   = calcDe(mat.E, mat.ν, "plane-stress")
    σtr  = state.σ + De*Δε
    ftr  = yield_func(mat, state, σtr, state.εpa)
    tol = 1e-8

    
    if ftr<tol
        # elastic
        state.Δλ = 0.0
        state.σ  = σtr
    else
        # plastic

        σ, εpa, Δλ, status = calc_σ_εpa_Δλ(mat, state, σtr)
        failed(status) && return state.σ, status

        state.σ, state.εpa, state.Δλ = σ, εpa, Δλ
    end

    state.ε += Δε
    Δσ     = state.σ - σini


    return Δσ, success()
end


function calc_σ_εpa_Δλ(mat::VonMises, state::VonMisesPlaneStressState, σtr::Vec6)
    # Δλ estimative
    De   = calcDe(mat.E, mat.ν, "plane-stress")
    # dfdσ = SVector( 2/3*σtr[1] - 1/3*σtr[2], 2/3*σtr[2] - 1/3*σtr[1], 0.0, σtr[4], σtr[5], σtr[6] )
    dfdσ = SVector( 2/3*σtr[1] - 1/3*σtr[2], 2/3*σtr[2] - 1/3*σtr[1], -1/3*σtr[1]-1/3*σtr[2], σtr[4], σtr[5], σtr[6] )

    Δλ0  = norm(σtr-state.σ)/norm(De*dfdσ)
    
    # find initial interval
    a = 0.0
    b = Δλ0

    σ, εpa = calc_σ_εpa(mat, state, σtr, a)
    fa     = yield_func(mat, state, σ, εpa)
    σ, εpa = calc_σ_εpa(mat, state, σtr, b)
    fb     = yield_func(mat, state, σ, εpa)

    # search for a valid interval
    if fa*fb>0
        maxits = 50
        for i in 1:maxits
            b  += Δλ0*(1.6)^i
            σ, εpa = calc_σ_εpa(mat, state, σtr, b)
            fb     = yield_func(mat, state, σ, εpa)
            fa*fb<0.0 && break

            i==maxits && return state.σ, 0.0, 0.0, failure("VonMises: Could not find interval for Δλ")
        end
    end

    ff(Δλ) = begin
        σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)
        yield_func(mat, state, σ, εpa)
    end

    tol = 10^-(8-log10(mat.σy))


    # findroot
    # Δλ, status = findroot(ff, a, b, tol)
    # failed(status) && return state.σ, 0.0, 0.0, status

    # σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)



    # @show (a,b)
    # @show status
    # @show yield_func(mat, state, σ, εpa)
    # @show σ
    # @show εpa



    # bissection method
    local f, Δλ, σ, εpa
    σ0  = zeros(SVector{6}) # initial value

    tol    = 10^-(10-log10(mat.σy))
    maxits = 50

    for i in 1:maxits
        Δλ = (a+b)/2
        σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)
        f = yield_func(mat, state, σ, εpa)

        # @show f
        # @show Δλ
        # error()

        if fa*f<0
            b = Δλ
        else
            a  = Δλ
            fa = f
        end

        maximum(abs, σ-σ0) <= tol && break
        σ0 = σ

        i==maxits && return state.σ, 0.0, 0.0, failure("VonMises: could not find Δλ with NR/bissection (maxits reached, f=$f)")
        # @show i
    end

    return σ, εpa, Δλ, success()   
end


function calc_σ_εpa(mat::VonMises, state::VonMisesPlaneStressState, σtr::Vec6, Δλ::Float64)
    E, ν = mat.E, mat.ν
    G    = E/(2*(1+ν))

    # σ at n+1
    den = E^2*Δλ^2 - 2*E*ν*Δλ + 4*E*Δλ - 3*ν^2 + 3
    m11 = (2*E*Δλ - E*ν*Δλ - 3*ν^2 + 3)/den
    m12 = (E*Δλ - 2*E*ν*Δλ)/den
    m66 = 1/(2*G*Δλ + 1)

    σ = SVector( 
        m11*σtr[1] + m12*σtr[2],
        m12*σtr[1] + m11*σtr[2], 
        0.0,
        m66*σtr[4], 
        m66*σtr[5], 
        m66*σtr[6]
    )

    dfdσ = SVector( 2/3*σ[1] - 1/3*σ[2], 2/3*σ[2] - 1/3*σ[1], -1/3*σ[1]-1/3*σ[2], σ[4], σ[5], σ[6] )

    εpa  = state.εpa + Δλ*norm(dfdσ)
    
    return σ, εpa
end


function ip_state_vals(mat::VonMises, state::VonMisesPlaneStressState)
    σ, ε  = state.σ, state.ε
    j1    = tr(σ)
    srj2d = √J2D(σ)

    D = stress_strain_dict(σ, ε, "plane-stress")
    D[:epa]   = state.εpa
    D[:j1]    = j1
    D[:srj2d] = srj2d

    return D
end


# VonMises model for beam elements


function yield_func(mat::VonMises, state::VonMisesBeamState, σ::Vec3, εpa::Float64)
    # f = 1/2 σ*Psd*σ - 1/3 (fy + H εp)^2
    # f = J2D - 1/3 (fy + H εp)^2
    # s = [ 2/3*σ1, -1/3*σ1, -1/3*σ1, 0.0, σ2, σ3 ]

    j2d = σ[1]^2/3 + σ[2]^2/2 + σ[3]^2/2

    σy  = mat.σy
    H   = mat.H
    return j2d - 1/3*(σy + H*εpa)^2
end


function calcD(mat::VonMises, state::VonMisesBeamState)
    E, ν = mat.E, mat.ν
    G    = E/2/(1+ν)
    De = @SMatrix [ E    0.0  0.0  
                    0.0  2*G  0.0  
                    0.0  0.0  2*G ]

    state.Δλ==0.0 && return De
    
    σ = state.σ
    dfdεp = -2/3*mat.H*(mat.σy + mat.H*state.εpa)

    s = SVector( 2/3*σ[1], -σ[1]/3, -σ[1]/3, 0.0, σ[2], σ[3] )

    De_dfdσ          = Vec3( 2/3*E*σ[1], 2*G*σ[2], 2*G*σ[3] ) # reduced vector
    De_dfdσ_dfdσ′_De = De_dfdσ*De_dfdσ'
    dfdσ′_De_dfdσ    = 4/9*E*σ[1]^2 + 2*G*σ[2]^2 + 2*G*σ[3]^2

    return De - De_dfdσ_dfdσ′_De / (dfdσ′_De_dfdσ - norm(s)*dfdεp)

end


function update_state!(mat::VonMises, state::VonMisesBeamState, Δε::Array{Float64,1})
    σini = state.σ
    
    E, ν = mat.E, mat.ν
    G    = E/2/(1+ν)
    De = @SMatrix [ 
        E    0.0  0.0  
        0.0  2*G  0.0  
        0.0  0.0  2*G 
    ]
    σtr = state.σ + De*Δε
    ftr = yield_func(mat, state, σtr, state.εpa)
    tol = 1e-8
    
    if ftr<tol
        # elastic
        state.Δλ = 0.0
        state.σ  = σtr
    else
        σ, εpa, Δλ, status = calc_σ_εpa_Δλ(mat, state, σtr)
        failed(status) && return state.σ, status

        state.σ, state.εpa, state.Δλ = σ, εpa, Δλ
    end

    state.ε += Δε
    Δσ     = state.σ - σini

    # @show σtr
    # @show state.σ
    # @show Δσ

    return Δσ, success()
end


function calc_σ_εpa_Δλ(mat::VonMises, state::VonMisesBeamState, σtr::Vec3)
    # Δλ estimative
    E, ν = mat.E, mat.ν
    G    = E/2/(1+ν)
    De = @SMatrix [ 
        E    0.0  0.0  
        0.0  2*G  0.0  
        0.0  0.0  2*G 
    ]

    dfdσ = SVector( 2/3*σtr[1], σtr[2], σtr[3] )
    
    Δλ0  = norm(σtr-state.σ)/norm(De*dfdσ)
    
    # find initial interval
    a = 0.0
    b = Δλ0

    σ, εpa = calc_σ_εpa(mat, state, σtr, a)
    fa     = yield_func(mat, state, σ, εpa)
    σ, εpa = calc_σ_εpa(mat, state, σtr, b)
    fb     = yield_func(mat, state, σ, εpa)

    # search for a valid interval
    if fa*fb>0
        maxits = 50
        for i in 1:maxits
            b  += Δλ0*(1.6)^i
            σ, εpa = calc_σ_εpa(mat, state, σtr, b)
            fb     = yield_func(mat, state, σ, εpa)
            fa*fb<0.0 && break

            i==maxits && return state.σ, 0.0, 0.0, failure("VonMises: Could not find interval for Δλ")
        end
    end

    ff(Δλ) = begin
        σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)
        yield_func(mat, state, σ, εpa)
    end

    tol = 10^-(8-log10(mat.σy))


    # findroot
    # Δλ, status = findroot(ff, a, b, tol)
    # failed(status) && return state.σ, 0.0, 0.0, status

    # σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)


    # bissection method
    local f, Δλ, σ, εpa
    σ0  = zeros(Vec3) # initial value

    tol    = 10^-(10-log10(mat.σy))
    maxits = 50

    for i in 1:maxits
        Δλ = (a+b)/2
        σ, εpa = calc_σ_εpa(mat, state, σtr, Δλ)
        f = yield_func(mat, state, σ, εpa)

        if fa*f<0
            b = Δλ
        else
            a  = Δλ
            fa = f
        end

        maximum(abs, σ-σ0) <= tol && break
        σ0 = σ

        i==maxits && return state.σ, 0.0, 0.0, failure("VonMises: could not find Δλ with NR/bissection (maxits reached, f=$f)")
    end

    return σ, εpa, Δλ, success()   
end


function calc_σ_εpa(mat::VonMises, state::VonMisesBeamState, σtr::Vec3, Δλ::Float64)
    E, ν = mat.E, mat.ν
    G    = E/(2*(1+ν))

    # σ at n+1
    σ = SVector( 
        3*σtr[1]/(2*E*Δλ + 3),
        σtr[2]/(2*G*Δλ + 1.5),
        σtr[3]/(2*G*Δλ + 1.5)
    )

    dfdσ = SVector( 2/3*σ[1], -1/3*σ[1], -1/3*σ[1], 0.0, σ[2], σ[3] )
    εpa  = state.εpa + Δλ*norm(dfdσ)
    
    return σ, εpa
end


function ip_state_vals(mat::VonMises, state::VonMisesBeamState)
    vals = OrderedDict{Symbol,Float64}(
        :sX  => state.σ[1],
        :eXp => state.ε[1],
        :sXY => state.σ[3]/SR2 # XY component is the third one
    )

    if state.env.ndim==3
        vals[:sXZ] = state.σ[2]/SR2 # adds the second component
    end

    return vals
end


# Von Mises for bar elements


function yield_func(mat::VonMises, state::VonMisesBarState, σ::Float64, εpa::Float64)
    return abs(σ) - (mat.σy + mat.H*εpa)
end


function calcD(mat::VonMises, state::VonMisesBarState)
    if state.Δλ == 0.0
        return mat.E
    else
        E, H = mat.E, mat.H
        return E*H/(E+H)
    end
end


function update_state!(mat::VonMises, state::VonMisesBarState, Δε::Float64)
    E, H    = mat.E, mat.H
    σini    = state.σ
    σtr     = σini + E*Δε
    ftr     = yield_func(mat, state, σtr, state.εpa)

    if ftr<0
        state.Δλ = 0.0
        state.σ   = σtr
    else
        state.Δλ  = ftr/(E+H)
        Δεp       = state.Δλ*sign(σtr)
        state.εpa += state.Δλ
        state.σ   = σtr - E*Δεp
    end

    Δσ        = state.σ - σini
    state.ε  += Δε
    return Δσ, success()
end


function ip_state_vals(mat::VonMises, state::VonMisesBarState)
    return OrderedDict{Symbol,Float64}(
        :sX  => state.σ,
        :eX  => state.ε,
        :eXp => state.εpa,
    )
end