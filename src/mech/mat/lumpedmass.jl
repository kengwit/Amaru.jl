# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export LumpedMass

mutable struct LumpedMassState<:IpState
    ctx::Context
    function LumpedMassState(ctx::Context)
        return new(ctx)
    end
end

mutable struct LumpedMass<:Material
    m::Float64

    function LumpedMass(prms::Dict{Symbol,Float64})
        return  LumpedMass(;prms...)
    end

    function LumpedMass(;m::Real=NaN)
        m>=0.0 || error("Invalid value for m: $m")
        return new(m)
    end
end



# Type of corresponding state structure
compat_state_type(::Type{LumpedMass}) = LumpedMassState

# Element types that work with this material
compat_elem_types(::Type{LumpedMass}) = (MechLumpedMass,)


function ip_state_vals(mat::LumpedMass, state::LumpedMassState)
    return OrderedDict{Symbol, Float64}()
end
