 #This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export MCJointSeep

mutable struct MCJointSeepIpState<:IpState
    env::ModelEnv
    σ   ::Array{Float64,1} # stress
    w   ::Array{Float64,1} # relative displacements
    uw  ::Float64  # fracture pore pressure
    upa ::Float64  # effective plastic relative displacement
    Δλ  ::Float64  # plastic multiplier
    h   ::Float64  # characteristic length from bulk elements
    time::Float64  # the time when the fracture opened
    function MCJointSeepIpState(env::ModelEnv=ModelEnv())
        this = new(env)
        ndim = env.ndim
        this.σ = zeros(ndim)
        this.w = zeros(ndim)
        this.uw = 0.0        
        this.upa = 0.0
        this.Δλ  = 0.0
        this.h  = 0.0
        this.time = 0.0
        return this
    end
end

mutable struct MCJointSeep<:Material
    E  ::Float64  # Young's modulus
    nu ::Float64  # Poisson ratio
    σmax0::Float64  # tensile strength (internal variable)
    θ  ::Float64  # tangent of friction angle
    αi ::Float64  # factor αi controls the elastic relative displacements 
    wc ::Float64  # critical crack opening
    ws ::Float64  # openning at inflection (where the curve slope changes)
    softcurve::String # softening curve model ("linear" or bilinear" or "hordijk")
    k ::Float64 # specific permeability
    γw::Float64 # water specific weight
    α ::Float64 # Biot's coefficient
    S ::Float64 # Storativity coefficient
    β ::Float64  # coefficient of compressibility
    μ ::Float64  # viscosity
    permeability::String # joint permeability specific permeability ("permeable" or "impermeable")

    function MCJointSeep(prms::Dict{Symbol,Float64})
        return  MCJointSeep(;prms...)
    end

     function MCJointSeep(;E=NaN, nu=NaN, ft=NaN, theta=NaN, alphai=NaN, wc=NaN, ws=NaN, GF=NaN, Gf=NaN, softcurve="bilinear", k=NaN, kappa=NaN, gammaw=NaN, alpha=NaN, S=NaN, beta=0.0, mu=NaN, permeability="permeable")
         #TODO: permeable=true;  

        !(isnan(GF) || GF>0) && error("Invalid value for GF: $GF")
        !(isnan(Gf) || Gf>0) && error("Invalid value for Gf: $Gf")

        if isnan(wc)
            if softcurve == "linear"
                 wc = round(2*GF/(1000*ft), digits=10)
            elseif softcurve == "bilinear"
                if isnan(Gf)
                    wc = round(5*GF/(1000*ft), digits=10)
                    ws = round(wc*0.15, digits=10)
                else
                    wc = round((8*GF- 6*Gf)/(1000*ft), digits=10)
                    ws = round(1.5*Gf/(1000*ft), digits=10)
                end
            elseif softcurve == "hordijk"
                wc = round(GF/(194.7019536*ft), digits=10)
            end    
        end

        if isnan(k) 
            k = (kappa*gammaw)/mu # specific permeability = (intrinsic permeability * water specific weight)/viscosity
        end

        E>0.0       || error("Invalid value for E: $E")
        0<=nu<0.5   || error("Invalid value for nu: $nu")

        ft<0         && error("Invalid value for ft: $ft")
        theta<0      && error("Invalid value for theta: $theta")
        alphai<0     && error("Invalid value for alphai: $alphai")
        !(isnan(ws) || ws>0) && error("Invalid value for ws: $ws")
        wc<0         && error("Invalid value for wc: $wc")
        !(softcurve=="linear" || softcurve=="bilinear" || softcurve=="hordijk") && error("Invalid softcurve: softcurve must to be linear or bilinear or hordijk")
        isnan(k)     && error("Missing value for k")
        isnan(gammaw) && error("Missing value for gammaw")
        !(gammaw>0)   && error("Invalid value for gammaw: $gammaw")
        !(alpha>0)   && error("Invalid value for alpha: $alpha")
        S<0.0        && error("Invalid value for S: $S")
        beta<0       && error("Invalid value for beta: $beta")
        mu<=0        && error("Invalid value for mu: $mu")
        !(permeability=="permeable" || permeability=="impermeable") && error("Invalid permeability: permeability must to be permeable or impermeable")

        this = new(E, nu, ft, theta, alphai, wc, ws, softcurve, k, gammaw, alpha, S, beta, mu, permeability)
        return this
    end
end

# Returns the element type that works with this material model
matching_elem_type(::MCJointSeep) = HydroMechJoint

# Create a new instance of Ip data
new_ip_state(mat::MCJointSeep, env::ModelEnv) = MCJointSeepIpState(env)


function yield_func(mat::MCJointSeep, ipd::MCJointSeepIpState, σ::Array{Float64,1})
    ndim = ipd.env.ndim
    σmax = calc_σmax(mat, ipd, ipd.upa)
    if ndim == 3
        return sqrt(σ[2]^2 + σ[3]^2) + (σ[1]-σmax)*mat.θ
    else
        return abs(σ[2]) + (σ[1]-σmax)*mat.θ
    end
end


function yield_deriv(mat::MCJointSeep, ipd::MCJointSeepIpState)
    ndim = ipd.env.ndim
    if ndim == 3
        return [ mat.θ, ipd.σ[2]/sqrt(ipd.σ[2]^2 + ipd.σ[3]^2), ipd.σ[3]/sqrt(ipd.σ[2]^2 + ipd.σ[3]^2)]
    else
        return [ mat.θ, sign(ipd.σ[2]) ]
    end
end


function potential_derivs(mat::MCJointSeep, ipd::MCJointSeepIpState, σ::Array{Float64,1})
    ndim = ipd.env.ndim
    if ndim == 3
            if σ[1] >= 0.0 
                # G1:
                r = [ 2.0*σ[1]*mat.θ^2, 2.0*σ[2], 2.0*σ[3]]
            else
                # G2:
                r = [ 0.0, 2.0*σ[2], 2.0*σ[3] ]
            end
    else
            if σ[1] >= 0.0 
                # G1:
                r = [ 2*σ[1]*mat.θ^2, 2*σ[2]]
            else
                # G2:
                r = [ 0.0, 2*σ[2] ]
            end
    end
    return r
end


function calc_σmax(mat::MCJointSeep, ipd::MCJointSeepIpState, upa::Float64)
	if mat.softcurve == "linear"
		if upa < mat.wc
            a = mat.σmax0
            b = mat.σmax0/mat.wc
		else
            a = 0.0
            b = 0.0
        end
        σmax = a - b*upa
    elseif mat.softcurve == "bilinear"
        σs = 0.25*mat.σmax0
        if upa < mat.ws
            a  = mat.σmax0 
            b  = (mat.σmax0 - σs)/mat.ws
        elseif upa < mat.wc
            a  = mat.wc*σs/(mat.wc-mat.ws)
            b  = σs/(mat.wc-mat.ws)
        else
            a = 0.0
            b = 0.0
        end
        σmax = a - b*upa
    elseif mat.softcurve == "hordijk"
        if upa < mat.wc
            z = (1 + 27*(upa/mat.wc)^3)*exp(-6.93*upa/mat.wc) - 28*(upa/mat.wc)*exp(-6.93)
        else
            z = 0.0
        end
        σmax = z*mat.σmax0
    end
    return σmax
end


function σmax_deriv(mat::MCJointSeep, ipd::MCJointSeepIpState, upa::Float64)
   # ∂σmax/∂upa = dσmax
    if mat.softcurve == "linear"
		if upa < mat.wc
            b = mat.σmax0/mat.wc
		else
            b = 0.0
        end
        dσmax = -b
    elseif mat.softcurve == "bilinear"
        σs = 0.25*mat.σmax0
        if upa < mat.ws
            b  = (mat.σmax0 - σs)/mat.ws
        elseif upa < mat.wc
            b  = σs/(mat.wc-mat.ws)
        else
            b = 0.0
        end
        dσmax = -b
    elseif mat.softcurve == "hordijk"
        if upa < mat.wc
            dz = ((81*upa^2*exp(-6.93*upa/mat.wc)/mat.wc^3) - (6.93*(1 + 27*upa^3/mat.wc^3)*exp(-6.93*upa/mat.wc)/mat.wc) - 0.02738402432/mat.wc)
        else
            dz = 0.0
        end
        dσmax = dz*mat.σmax0
    end
    return dσmax
end


function calc_kn_ks_De(mat::MCJointSeep, ipd::MCJointSeepIpState)
    ndim = ipd.env.ndim
    kn = mat.E*mat.αi/ipd.h
    G  = mat.E/(2.0*(1.0+mat.nu))
    ks = G*mat.αi/ipd.h

    if ndim == 3
        De = [  kn  0.0  0.0
               0.0   ks  0.0
               0.0  0.0   ks ]
    else
        De = [  kn   0.0
                 0.0  ks  ]
    end

    return kn, ks, De
end


function calc_Δλ(mat::MCJointSeep, ipd::MCJointSeepIpState, σtr::Array{Float64,1})
    ndim = ipd.env.ndim
    maxits = 50
    Δλ     = 0.0
    f      = 0.0
    upa    = 0.0
    tol    = 1e-4      

    for i=1:maxits
        θ      = mat.θ
    	kn, ks, De = calc_kn_ks_De(mat, ipd)

		# quantities at n+1
		if ndim == 3
			if σtr[1]>0
			     σ     = [ σtr[1]/(1+2*Δλ*kn*θ^2),  σtr[2]/(1+2*Δλ*ks),  σtr[3]/(1+2*Δλ*ks) ]
			     dσdΔλ = [ -2*kn*θ^2*σtr[1]/(1+2*Δλ*kn*θ^2)^2,  -2*ks*σtr[2]/(1+2*Δλ*ks)^2,  -2*ks*σtr[3]/(1+2*Δλ*ks)^2 ]
			     drdΔλ = [ -4*kn*θ^4*σtr[1]/(1+2*Δλ*kn*θ^2)^2,  -4*ks*σtr[2]/(1+2*Δλ*ks)^2,  -4*ks*σtr[3]/(1+2*Δλ*ks)^2 ]
			else
			     σ     = [ σtr[1],  σtr[2]/(1+2*Δλ*ks),  σtr[3]/(1+2*Δλ*ks) ]
			     dσdΔλ = [ 0,  -2*ks*σtr[2]/(1+2*Δλ*ks)^2,  -2*ks*σtr[3]/(1+2*Δλ*ks)^2 ]
			     drdΔλ = [ 0,  -4*ks*σtr[2]/(1+2*Δλ*ks)^2,  -4*ks*σtr[3]/(1+2*Δλ*ks)^2 ]
			end
		else
			if σtr[1]>0
			     σ     = [ σtr[1]/(1+2*Δλ*kn*θ^2),  σtr[2]/(1+2*Δλ*ks) ]
			     dσdΔλ = [ -2*kn*θ^2*σtr[1]/(1+2*Δλ*kn*θ^2)^2,  -2*ks*σtr[2]/(1+2*Δλ*ks)^2 ]
			     drdΔλ = [ -4*kn*θ^4*σtr[1]/(1+2*Δλ*kn*θ^2)^2,  -4*ks*σtr[2]/(1+2*Δλ*ks)^2 ]
			else
			     σ     = [ σtr[1],  σtr[2]/(1+2*Δλ*ks) ]
			     dσdΔλ = [ 0,  -2*ks*σtr[2]/(1+2*Δλ*ks)^2 ]
			     drdΔλ = [ 0,  -4*ks*σtr[2]/(1+2*Δλ*ks)^2 ]
			 end
		end
			 	
		 r      = potential_derivs(mat, ipd, σ)
		 norm_r = norm(r)
		 upa    = ipd.upa + Δλ*norm_r
		 σmax   = calc_σmax(mat, ipd, upa)
		 m      = σmax_deriv(mat, ipd, upa)
		 dσmaxdΔλ = m*(norm_r + Δλ*dot(r/norm_r, drdΔλ))

		if ndim == 3
		    f = sqrt(σ[2]^2 + σ[3]^2) + (σ[1]-σmax)*θ
		    if (σ[2]==0 && σ[3]==0) 
		        dfdΔλ = (dσdΔλ[1] - dσmaxdΔλ)*θ		      
		    else
		        dfdΔλ = 1/sqrt(σ[2]^2 + σ[3]^2) * (σ[2]*dσdΔλ[2] + σ[3]*dσdΔλ[3]) + (dσdΔλ[1] - dσmaxdΔλ)*θ
		    end
		else
			f = abs(σ[2]) + (σ[1]-σmax)*mat.θ
			dfdΔλ = sign(σ[2])*dσdΔλ[2] + (dσdΔλ[1] - dσmaxdΔλ)*θ
		end
        
        Δλ = Δλ - f/dfdΔλ

        abs(f) < tol && break

        if i == maxits || isnan(Δλ)
            @error """MCJointSeep: Could not find Δλ. This may happen when the system
            becomes hypostatic and thus the global stiffness matrix is near syngular.
            Increasing the mesh refinement may result in a nonsingular matrix.
            """ iterations=i Δλ
            error()
        end
    end
    return Δλ
end


function calc_σ_upa(mat::MCJointSeep, ipd::MCJointSeepIpState, σtr::Array{Float64,1})
    ndim = ipd.env.ndim
    θ = mat.θ
    kn, ks, De = calc_kn_ks_De(mat, ipd)

    if ndim == 3
        if σtr[1] > 0
            σ = [σtr[1]/(1 + 2*ipd.Δλ*kn*(θ^2)), σtr[2]/(1 + 2*ipd.Δλ*ks), σtr[3]/(1 + 2*ipd.Δλ*ks)]
        else
            σ = [σtr[1], σtr[2]/(1 + 2*ipd.Δλ*ks), σtr[3]/(1 + 2*ipd.Δλ*ks)]
        end    
    else
        if σtr[1] > 0
            σ = [σtr[1]/(1 + 2*ipd.Δλ*kn*(θ^2)), σtr[2]/(1 + 2*ipd.Δλ*ks)]
        else
            σ = [σtr[1], σtr[2]/(1 + 2*ipd.Δλ*ks)]
        end    
    end
    ipd.σ = σ
    r = potential_derivs(mat, ipd, ipd.σ)
    ipd.upa += ipd.Δλ*norm(r)
    return ipd.σ, ipd.upa
end


function mountD(mat::MCJointSeep, ipd::MCJointSeepIpState)
    ndim = ipd.env.ndim
    kn, ks, De = calc_kn_ks_De(mat, ipd)
    σmax = calc_σmax(mat, ipd, ipd.upa)

    if ipd.Δλ == 0.0  # Elastic 
        return De
    elseif σmax == 0.0 
        Dep  = De*1e-10 
        return Dep
    else
        v    = yield_deriv(mat, ipd)
        r    = potential_derivs(mat, ipd, ipd.σ)
        y    = -mat.θ # ∂F/∂σmax
        m    = σmax_deriv(mat, ipd, ipd.upa)  # ∂σmax/∂upa

        #Dep  = De - De*r*v'*De/(v'*De*r - y*m*norm(r))

        if ndim == 3
            den = kn*r[1]*v[1] + ks*r[2]*v[2] + ks*r[3]*v[3] - y*m*norm(r)

            Dep = [   kn - kn^2*r[1]*v[1]/den    -kn*ks*r[1]*v[2]/den      -kn*ks*r[1]*v[3]/den
                     -kn*ks*r[2]*v[1]/den         ks - ks^2*r[2]*v[2]/den  -ks^2*r[2]*v[3]/den
                     -kn*ks*r[3]*v[1]/den        -ks^2*r[3]*v[2]/den        ks - ks^2*r[3]*v[3]/den ]
        else
            den = kn*r[1]*v[1] + ks*r[2]*v[2] - y*m*norm(r)

            Dep = [   kn - kn^2*r[1]*v[1]/den    -kn*ks*r[1]*v[2]/den      
                     -kn*ks*r[2]*v[1]/den         ks - ks^2*r[2]*v[2]/den  ]
        end

    	return Dep
    end
end


function stress_update(mat::MCJointSeep, ipd::MCJointSeepIpState, Δw::Array{Float64,1}, Δuw::Float64, time::Float64)
    ndim = ipd.env.ndim
    σini = copy(ipd.σ)

    θ = mat.θ
    kn, ks, De = calc_kn_ks_De(mat, ipd)
    σmax = calc_σmax(mat, ipd, ipd.upa) 


    if isnan(Δw[1]) || isnan(Δw[2])
        @show Δw[1]
        @show Δw[2]
        exit()
    end

    # σ trial and F trial
    σtr  = ipd.σ + De*Δw

    Ftr  = yield_func(mat, ipd, σtr) 

    # Elastic and EP integration
    if σmax == 0.0 && ipd.w[1] >= 0.0
        if ndim==3
            r1 = [ σtr[1]/kn, σtr[2]/ks, σtr[3]/ks ]
            r = r1/norm(r1)
            ipd.Δλ = norm(r1)
        else
            r1 = [ σtr[1]/kn, σtr[2]/ks ]
            r = r1/norm(r1)
            ipd.Δλ = norm(r1)  
        end

        ipd.upa += ipd.Δλ
        ipd.σ = σtr - ipd.Δλ*De*r     

    elseif Ftr <= 0.0
        # Pure elastic increment
        ipd.Δλ = 0.0
        ipd.σ  = copy(σtr) 

    else    
        ipd.Δλ = calc_Δλ(mat, ipd, σtr) 
        ipd.σ, ipd.upa = calc_σ_upa(mat, ipd, σtr)
                      
        # Return to surface:
        F  = yield_func(mat, ipd, ipd.σ)   
        if F > 1e-3
            warn("stress_update: The value of the yield function is $F")
        end
    end

    if  ipd.upa != 0.0 && ipd.time == 0.0
        ipd.time = time 
    end

        ipd.w += Δw
        Δσ = ipd.σ - σini

        ipd.uw += Δuw

    return Δσ
end


function ip_state_vals(mat::MCJointSeep, ipd::MCJointSeepIpState)
    ndim = ipd.env.ndim
    if ndim == 3
       return Dict(
          :w1  => ipd.w[1] ,
          :w2  => ipd.w[2] ,
          :w3  => ipd.w[3] ,
          :s1  => ipd.σ[1] ,
          :s2  => ipd.σ[2] ,
          :s3  => ipd.σ[3] ,
          :upa => ipd.upa
          )
    else
        return Dict(
          :w1  => ipd.w[1] ,
          :w2  => ipd.w[2] ,
          :s1  => ipd.σ[1] ,
          :s2  => ipd.σ[2] ,
          :upa => ipd.upa
          )
    end
end
