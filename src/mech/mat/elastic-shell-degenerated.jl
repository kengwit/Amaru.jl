# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export ElasticShellDegenerated

mutable struct ElasticShellDegeneratedState<:IpState
    env::ModelEnv
    σ::Array{Float64,1}
    function ElasticShellDegeneratedState(env::ModelEnv=ModelEnv())
        σ = zeros(5)
        return new(env, σ)
    end
end

mutable struct ElasticShellDegenerated<:MatParams
    E::Float64
    nu::Float64
    t::Float64

    function ElasticShellDegenerated(prms::Dict{Symbol,Float64})
        return  ElasticShellDegenerated(;prms...)
    end

    function ElasticShellDegenerated(;E=NaN, nu=NaN, thickness=0.1)
        E>0.0 || error("Invalid value for E: $E")
        (0<=nu<0.5) || error("Invalid value for nu: $nu")
        thickness >0.0 || error("Invalid value for thickness: $thickness")
        this = new(E, nu, thickness)
        return this
    end
end

matching_elem_type(::ElasticShellDegenerated) = ShellDegeneratedElem

# Type of corresponding state structure
ip_state_type(matparams::ElasticShellDegenerated) = ElasticShellDegeneratedState


function ip_state_vals(matparams::ElasticShellDegenerated, state::ElasticShellDegeneratedState)
    return OrderedDict{Symbol, Float64}()
end