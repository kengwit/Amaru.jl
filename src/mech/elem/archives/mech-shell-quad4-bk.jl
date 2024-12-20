# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

export ShellQUAD4

mutable struct ShellQUAD4<:Mech
    id    ::Int
    shape ::CellShape
    nodes ::Array{Node,1}
    ips   ::Array{Ip,1}
    tag   ::String
    mat::Material
    active::Bool
    linked_elems::Array{Element,1}
    ctx::Context

    function ShellQUAD4()
        return new()
    end
end

compat_shape_family(::Type{ShellQUAD4}) = BULKCELL


# the strain-displacement matrix for membrane forces
function Dm_maxtrix(elem::ShellQUAD4)

    coef1 = elem.mat.t*elem.mat.E/(1-elem.mat.ν^2)
    coef2 = elem.mat.ν*coef1
    coef3 = coef1*(1-elem.mat.ν)/2

        Dm = [coef1  coef2 0
                  coef2  coef1 0
                  0      0     coef3]
    return Dm
end

# the strain-displacement matrix for bending moments
function Db_maxtrix(elem::ShellQUAD4)

    Dm = Dm_maxtrix(elem)

    Db = Dm*(elem.mat.t^2/12)

    return Db
end

# the strain-displacement matrix for shear forces


function Ds_maxtrix(elem::ShellQUAD4)

    coef = elem.mat.t*(5/6)*elem.mat.E/(2*(1+elem.mat.ν))

            Ds = [coef    0
                        0     coef]
    return Ds
end

# Rotation Matrix
function RotMatrix(elem::ShellQUAD4, J::Matrix{Float64})
    
    Z = zeros(1,2) # zeros(2,1)

    if size(J,1)==2
        J = [J
             Z]
    else
        J = J
    end
    
    L1 = vec(J[:,1])
    L2 = vec(J[:,2])
    L3 = cross(L1, L2)  # L1 is normal to the first element face
    L2 = cross(L1, L3)
    normalize!(L1)
    normalize!(L2)
    normalize!(L3)

    Z1 = zeros(1,2) # Z = zeros(1,3)

    Rot = [ L2' Z1
    L1' Z1
    L3' Z1
    Z1   L2'
    Z1   L1']

    return Rot
             
end


function elem_config_dofs(elem::ShellQUAD4)
    ndim = elem.ctx.ndim
    ndim == 1 && error("ShellQUAD4: Shell elements do not work in 1d analyses")
    #if ndim==2
        for node in elem.nodes
            add_dof(node, :ux, :fx)
            add_dof(node, :uy, :fy)
            add_dof(node, :uz, :fz)
            add_dof(node, :rx, :mx)
            add_dof(node, :ry, :my)
        end
    #else
        #error("ShellQUAD4: Shell elements do not work in this analyses")
        #=
        for node in elem.nodes
            add_dof(node, :ux, :fx)
            add_dof(node, :uy, :fy)
            add_dof(node, :uz, :fz)
            add_dof(node, :rx, :mx)
            add_dof(node, :ry, :my)
            add_dof(node, :rz, :mz)
        end
        =#
    #end
end


function elem_map(elem::ShellQUAD4)::Array{Int,1}

    #if elem.ctx.ndim==2
    #    dof_keys = (:ux, :uy, :uz, :rx, :ry)
    #else
    #    dof_keys = (:ux, :uy, :uz, :rx, :ry, :rz) # VERIFICAR
    #end

    dof_keys = (:ux, :uy, :uz, :rx, :ry)

    vcat([ [node.dofdict[key].eq_id for key in dof_keys] for node in elem.nodes]...)

end


function setBb(elem::ShellQUAD4, N::Vect, dNdX::Matx, Bb::Matx)
    nnodes = length(elem.nodes)
    # ndim, nnodes = size(dNdX)
    ndof = 5
    Bb .= 0.0
   
    for i in 1:nnodes
        dNdx = dNdX[i,1]
        dNdy = dNdX[i,2]
        j    = i-1

        Bb[1,4+j*ndof] = -dNdx  
        Bb[2,5+j*ndof] = -dNdy   
        Bb[3,4+j*ndof] = -dNdy 
        Bb[3,5+j*ndof] = -dNdx 

    end
end


function setBm(elem::ShellQUAD4, N::Vect, dNdX::Matx, Bm::Matx)
    nnodes = length(elem.nodes)
    # ndim, nnodes = size(dNdX)
    ndof = 5
    Bm .= 0.0
   
    for i in 1:nnodes
        dNdx = dNdX[i,1]
        dNdy = dNdX[i,2]
        j    = i-1

        Bm[1,1+j*ndof] = dNdx  
        Bm[2,2+j*ndof] = dNdy   
        Bm[3,1+j*ndof] = dNdy 
        Bm[3,2+j*ndof] = dNdx 

    end
end


function setBs_bar(elem::ShellQUAD4, N::Vect, dNdX::Matx, Bs_bar::Matx)
    nnodes = length(elem.nodes)

    cx = [ 0 1 0 -1]
    cy = [-1 0 1 0 ]

    Bs_bar .= 0.0
    Ns= zeros(4,1)
    
    for i in 1:nnodes
      Ns[1] = (1-cx[i])*(1-cy[i])/4
      Ns[2] = (1+cx[i])*(1-cy[i])/4
      Ns[3] = (1+cx[i])*(1+cy[i])/4
      Ns[4] = (1-cx[i])*(1+cy[i])/4

      bs1  = [ dNdX[1,1] -Ns[1]    0
               dNdX[1,2]     0 -Ns[1]];

      bs2  = [ dNdX[2,1] -Ns[2]    0
               dNdX[2,2]     0 -Ns[2]]

      bs3  = [ dNdX[3,1] -Ns[3]    0
               dNdX[3,2]     0 -Ns[3]]

      bs4  = [ dNdX[4,1] -Ns[4]    0
               dNdX[4,2]     0 -Ns[4]]

          bs = [bs1 bs2 bs3 bs4]

          Bs_bar[2*i-1:2*i,:] = bs[1:2,:]
    end
end


function elem_stiffness(elem::ShellQUAD4)

    nnodes = length(elem.nodes)

    Db = Db_maxtrix(elem)
    Dm = Dm_maxtrix(elem)
    Ds = Ds_maxtrix(elem)

    Bb = zeros(3, nnodes*5)
    Bm = zeros(3, nnodes*5)
    Bs_bar = zeros(8,nnodes*3)

    c  = zeros(8,8)
    nr = 5   
    nc = 5
    R = zeros(nnodes*nr, nnodes*nc)
    Kelem = zeros( nnodes*5 , nnodes*5 )

    C = getcoords(elem)

    if size(C,2)==2
        cxyz  = zeros(4,3)
        cxyz[:,1:2]  = C
    else
        cxyz = C
    end
    
    for ip in elem.ips      
        # compute shape Jacobian
        N    = elem.shape.func(ip.R)
        dNdR = elem.shape.deriv(ip.R)

        J = cxyz'*dNdR

        Ri = RotMatrix(elem, J)
        Ri′ = Ri[1:2, 1:3]
    
        ctxy = cxyz*Ri[1:3, 1:3]' # Rotate coordinates to element mid plane
      
        dNdX = dNdR*pinv(J)

        dNdX′ = dNdX*(Ri′)'
              
        for i in 1:nnodes
            R[(i-1)*nr+1:i*nr, (i-1)*nc+1:i*nc] = Ri
        end     
   
        J1 = ctxy'*dNdR
        invJ1  =  pinv(J1)
        detJ1 = norm2(J1)

        for i in 1:nnodes
            c[(i-1)*2+1:i*2, (i-1)*2+1:i*2] = J1[1:2,1:2]
        end

        setBb(elem, N, dNdX′, Bb)
        setBm(elem, N, dNdX′, Bm)
        setBs_bar(elem, N, dNdX′, Bs_bar)

                    T_mat = [ 1  0  0  0  0  0  0  0
                              0  0  0  1  0  0  0  0
                              0  0  0  0  1  0  0  0
                              0  0  0  0  0  0  0  1 ]

                    P_mat = [ 1  -1   0   0
                              0   0   1   1
                              1   1   0   0
                              0   0   1  -1 ]
       
                    A_mat = [ 1  ip.R[2] 0    0
                              0    0  1  ip.R[1]]
      
                    bmat_ss = invJ1[1:2, 1:2]* A_mat * inv(P_mat) * T_mat * c * Bs_bar

                    bmat_s1 = [0  0 bmat_ss[1, 1]
                               0  0 bmat_ss[2, 1]]

                    bmat_s2 = [0  0 bmat_ss[1, 4]
                               0  0 bmat_ss[2, 4]]

                    bmat_s3 = [0  0 bmat_ss[1, 7]
                               0  0 bmat_ss[2, 7]]

                    bmat_s4 = [0  0 bmat_ss[1,10]
                               0  0 bmat_ss[2,10]]

                    bmat_s1 = [bmat_s1*Ri[1:3, 1:3]  bmat_ss[:,2:3]]
                    bmat_s2 = [bmat_s2*Ri[1:3, 1:3] bmat_ss[:,5:6]]
                    bmat_s3 = [bmat_s3*Ri[1:3, 1:3] bmat_ss[:,8:9]]
                    bmat_s4 = [bmat_s4*Ri[1:3, 1:3] bmat_ss[:,11:12]]

                    bmat_s = [bmat_s1 bmat_s2 bmat_s3 bmat_s4]

                    coef = detJ1*ip.w

                     Kb =    Bb'*Db*Bb*coef 
                     Km = R'*Bm'*Dm*Bm*R*coef 
                     Ks = bmat_s'*Ds*bmat_s*coef 

                     Kelem += (Kb + Km + Ks)
            end
        map = elem_map(elem) 
    return Kelem, map, map
end


function update_elem!(elem::ShellQUAD4, U::Array{Float64,1}, dt::Float64)
    K, map, map = elem_stiffness(elem)
    dU  = U[map]
    F[map] += K*dU
    return success()
end
