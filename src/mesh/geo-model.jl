export Point, Line, Loop, PlaneSurface, Surface, GeoModel
export addpoint!, addline!, addarc!, addloop!, addplanesurface!, addvolume!, addblock!

mutable struct GeoModel
    points::Vector{Point}
    lines::Vector{AbstractLine}
    loops::Vector{AbstractLoop}
    surfaces::Vector{AbstractSurface}
    volumes::Vector{Volume}
    supp_paths::Vector{SupPath}
    blocks::Vector{Block}
    size::Float64
    _id::Int

    function GeoModel(; size=0.0)
        return new( [], [], [], [], [], [], [], size, 0 )
    end
end

Base.show(io::IO, geo::GeoModel) = _show(io, geo, 3, "")

function addblock!(geo::GeoModel, block::Block)
    push!(geo.blocks, block)
end

function getpoint(geo::GeoModel, p::Point)
    for pp in geo.points
        p==pp && return pp
    end

    return nothing
end

function getline(geo::GeoModel, line::AbstractLine)
    idx = findfirst(==(line), geo.lines)
    idx === nothing && (idx=0) 
    return get(geo.lines, idx, nothing)
end

function getline(geo::GeoModel, p1::Point, p2::Point)
    l = Line(p1, p2)
    return getline(geo, l)
end

function getloop(geo::GeoModel, loop::AbstractLoop)
    idx = findfirst(==(loop), geo.loops)
    idx === nothing && return idx
    return geo.loops[idx]
end

function getsurface(geo::GeoModel, surf::AbstractSurface)
    idx = findfirst(==(surf), geo.surfaces)
    idx === nothing && return idx
    return geo.surfaces[idx]
end

function getvolume(geo::GeoModel, vol::Volume)
    idx = findfirst(==(vol), geo.volumes)
    idx === nothing && return idx
    return geo.volumes[idx]
end


function Base.delete!(geo::GeoModel, line::Line)
    filter!(!=(line), geo.lines)

    p1 = line.points[1]
    p2 = line.points[end]

    filter!(!=(line), p1.lines)
    filter!(!=(line), p2.lines)

    # delete surfaces associated with that line
    for s in line.surfaces
        for lo in s.loops
            line in lo.lines && delete!(geo, s)
        end
    end
end


function Base.delete!(geo::GeoModel, surf::AbstractSurface)
    filter!(!=(surf), geo.surfaces)

    if !isa(surf, PlaneSurface) 
        # delete loop if not plane surface
        delete!(geo.loops, lo) # todo: check
    else
        # check if loop is used elsewhere
        for lo in surf.loops
            # for each curve remove links to this surface
            for l in lo.lines
                filter!(!=(surf), l.surfaces)
            end 
    
            # check if other surfaces uses this loop
            found = false
            for s in geo.surfaces
                s.id==surf.id && continue
                s isa PlaneSurface || continue
                if lo in s.loops
                    found = true
                    break
                end
            end
    
            !found && delete!(geo.loops, lo) # todo: check
        end
    end

    # remove volumes that uses this surface # todo
    # for v in geo.volumes
    #     surf in v.surfaces && delete!(geo, v)
    # end
end


function insegment(X, X1, X2)
    tol = 1e-8
    X1X = X-X1
    X1X2 = X2-X1
    norm(cross(X1X2, X1X)) > tol && return false # check colinearity
    dot1 = dot(X1X2, X1X)
    dot2 = dot(X1X2, X1X2)
    return tol < dot1 < dot2-tol # check if inside segment within tol
end

function insegment(p::Point, p1::Point, p2::Point)
    return insegment(p.coord, p1.coord, p2.coord)
end


@enum(GeoFindStatus,
    OUTSIDE  = 0,
    INSIDE   = 1,
    ATPOINT  = 2,
    ATBORDER = 3,
)

function point_in_line(p::Point, l::Line)

    p in l.points[[1,end]] && return ATPOINT

    # tol = 1e-8
    X = p.coord
    X1 = l.points[1].coord
    X2 = l.points[end].coord

    X1X = X-X1
    X1X2 = X2-X1
    norm(cross(X1X2, X1X)) > tol && return false # check colinearity
    dot1 = dot(X1X2, X1X)
    dot2 = dot(X1X2, X1X2)

    0 < dot1 < dot2 && return INSIDE

    return OUTSIDE
end


function coplanar(P::Plane, l::AbstractLine)
    tol = 1e-8 

    for p in l.points # check if every point is in the plane
        abs(dot(P.normal, p.coord) - P.distance) > tol && return false
    end

    return true
end


function coplanar(P::Plane, p::Point)
    tol = 1e-8 
    abs(dot(P.normal, p.coord) - P.distance) < tol && return true
    return false
end


function addpoint!(geo::GeoModel, pt::Point)
    p = getpoint(geo, pt)
    p===nothing || return p

    # add point
    geo._id +=1
    pt.id = geo._id
    push!(geo.points, pt)

    # check if point is inside any existing line
    for l in geo.lines
        p1 = l.points[1]
        p2 = l.points[end]
        if insegment(pt.coord, p1.coord, p2.coord)
            newline = addsingleline!(geo, pt, p2, n=div(l.n,2), tag=l.tag) # create a new line
            l.points = [ p1, pt ] # updagte original line
            pt.lines = GeoEntity[ l, newline ] # update pt links
            filter!(!=(l), p2.lines) # remove ref to l in p2

            # update existing loops that contained the original line
            for lo in geo.loops
                idx = findfirst(==(l), lo.lines)
                idx===nothing && continue
                idxp1 = idx % length(lo.lines) + 1
                bothlines = [ l, newline ]
                p2 in lo.lines[idxp1].points || reverse!(bothlines)
                lo.lines = [ lo.lines[1:idx-1]; bothlines; lo.lines[idx+1:end] ]
            end

            newline.surfaces = copy(l.surfaces)
            break
        end
    end

    return pt
end


function addpoint!(geo::GeoModel, x, y, z=0.0; size=0.0, tag="")
    return addpoint!(geo, Point(x,y,z; size=size, tag=tag))
end


function addpoint!(geo::GeoModel, X::AbstractArray; size=0.0, tag="")
    X = Vec3(X)
    return addpoint!(geo, Point(X[1],X[2],X[3]; size=size, tag=tag))
end

function Base.copy!(geo::GeoModel, p::Point; dx=0.0, dy=0.0, dz=0.0)
    pp = Point(p.coord .+ [dx, dy, dz]; size=p.size, tag=p.tag)
    pp = addpoint!(geo, pp)
    return pp
end

# This fuction just adds a line without searching for loops
function addsingleline!(geo::GeoModel, p1::Point, p2::Point; n=0, tag="")
    l = getline(geo, p1, p2)

    if l !== nothing
        l.n = n
        return l
    end

    line = Line(p1, p2, n=n, tag=tag)

    geo._id +=1
    line.id = geo._id

    push!(geo.lines, line)
    push!(p1.lines, line)
    push!(p2.lines, line)
    return line
end


# This fuction just adds an arc without searching for loops
function addsinglearc!(geo::GeoModel, p1::Point, p2::Point, p3::Point; n=0, tag="")
    p1 = getpoint(geo, p1)
    p2 = getpoint(geo, p2)
    p3 = getpoint(geo, p3)

    arc = Arc(p1, p2, p3, n=n, tag=tag)
    a = getline(geo, arc)
    a===nothing || return a

    # add arc
    geo._id +=1
    arc.id = geo._id

    push!(geo.lines, arc)
    push!(p1.lines, arc)
    push!(p3.lines, arc)

    return arc
end


function addsingleloop!(geo::GeoModel, loop::AbstractLoop)
    lo = getloop(geo, loop)
    lo===nothing || return lo

    geo._id +=1
    loop.id = geo._id
    push!(geo.loops, loop)

    return loop
end


function intersection(l1::Line, l2::Line)
    # Assumes:
    # L1: P = P1 +V1*t
    # L2: Q = Y2 +V2*s
    # V1 = P2-P1
    # V2 = Q2-Q1

    tol = 1e-8
    P1 = l1.points[1].coord
    P2 = l1.points[end].coord
    V1 = P2-P1

    Q1 = l2.points[1].coord
    Q2 = l2.points[end].coord
    V2 = Q2-Q1

    #check if they are parallel or colinear
    norm(cross(V1, V2)) > tol || return nothing

    # check if lines are coplanar
    abs(dot(cross(V1,V2), P1-Q1)) < tol || return nothing

    # intersection point
    v1² = dot(V1,V1)
    v2² = dot(V2,V2)
    v1v2 = dot(V1,V2)
    s = ( dot(Q1-P1, V2)*v1² - dot(Q1-P1,V1)*v1v2) / (v1v2^2 - v1²*v2²)
    t = ( dot(Q1-P1, V1) + v1v2*s) / v1²

    # check if the intersection point is inside segments
    (-tol < s < 1+tol && -tol < t < 1+tol) || return nothing

    X = P1 + t*V1

    return Point(X...)
end


function findloops(line::AbstractLine; lines::Vector{<:AbstractLine}=AbstractLine[], inner=true)
    
    # get a list of lines adjacent to the last point of l
    function candidates(visited::Vector{<:AbstractLine})
        l1 = visited[end]

        if length(visited)==1
            cands = copy(line.points[end].lines)
        else
            l0 = visited[end-1]
            p1, p2 = l1.points[[1, end]]
            if p1 in l0.points
                cands = copy(p2.lines)
            else
                cands = copy(p1.lines)
            end
        end

        length(lines)>0 && intersect!(cands, lines) # warning: intersect uses hash
        filter!(!=(l1), cands)

        return cands
    end

    function findloops(visited::Vector{<:AbstractLine}, line::AbstractLine,  plane::Union{Plane,Nothing})
        if length(visited)>=2
            # todo: improve using directional graph

            idx = findfirst(==(line), visited)
            if idx==1
                visited[1].points[end] in visited[end].points && return Loop[] # closed from the wrong direction
                return [ PlaneLoop(visited) ]
            elseif idx!==nothing # discard loop (does not contain initial point)
                return PlaneLoop[]
            end

            visited[1].points[1] in line.points[[1,end]] && return [ PlaneLoop([visited; line]) ] # checking initial point
        end

        visited = [visited; line] # make a new list

        if plane===nothing && length(visited)>1
            points = [visited[1].points; line.points]
            if !colinear(points)
                plane = Plane([visited[1].points; line.points]) 
            end
        end

        function checkplane(l::AbstractLine)
            plane===nothing && return true
            inner && return true
            # check lines with less than 2 linnked surfaces
            surfs = collect(Set(s for s in l.surfaces))
            filter!(s -> s isa PlaneSurface, surfs)
            filter!(s -> s.plane==plane, surfs)
            return length(surfs)<2
        end
        
        cands = candidates(visited)
        filter!(checkplane, cands)


        # check if loop is closed
        # if length(visited)>=2
        #     line1 = visited[1]
        #     idx = findfirst(==(line1), candidates)
        #     if idx !== nothing # loop found
        #         line1.points[end] in line[end].points && return Loop
        #     end
        # end

        loops = PlaneLoop[]
        for l in cands
            append!(loops, findloops(visited, l, plane))
        end

        return loops
    end

    return findloops(AbstractLine[], line, nothing)

end


function findsurface(geo::GeoModel, l::AbstractLine)
    p1 = l.points[1]
    p2 = l.points[end]
    s1 = [s for l in p1.lines for s in l.surfaces]
    s2 = [s for l in p2.lines for s in l.surfaces]
    surfs = intersect(s1, s2)

    length(surfs)==1 && return surfs[1]
    
    for s in geo.surfaces
        s isa PlaneSurface || continue
        coplanar(s.plane, l) || continue
        inside(l.points, s) && return s
    end

    return nothing
end


function addline!(geo::GeoModel, p1::Point, p2::Point; n=0, tag="")
    l = Line(p1, p2)
    ll = getline(geo, l)
    ll===nothing || return ll
    len = norm(p1.coord-p2.coord)
    
    points = Point[]
    
    # check if line intersects other lines
    for li in geo.lines
        li isa Line || continue
        p = intersection(li, l)
        p === nothing && continue
        push!(points, p)
    end

    # check if line lies over control points
    for li in geo.lines
        li isa Arc || continue
        p = li.points[2]
        insegment(p, p1, p2) && push!(points, p)
    end

    # sort points    
    push!(points, p1)
    push!(points, p2)
    points = collect(Set(points))
    sort!(points, by=p->norm(p.coord-p1.coord))

    # add missing points and update references (may update loops)
    points = [ addpoint!(geo, p) for p in points ]
    
    # add lines
    npts = length(points)
    for i in 1:npts-1
        p1 = points[i]
        p2 = points[i+1]
        ni = trunc(Int, len/norm(p1.coord-p2.coord)*n)
        l = addsingleline!(geo, p1, p2, n=ni, tag=tag)

        # check if l is an endline
        (length(p1.lines)==1 || length(p2.lines)==1) && continue

        s = findsurface(geo, l)

        if s!==nothing # line divides s into two surfaces
            # find all lines inside s including the border
            lines = [ l for l in geo.lines if inside(l.points, s) ]
            lines = [ l; lines ]
            
            loops = findloops(l, lines=lines, inner=true)

            if length(loops)==0
                continue
            elseif length(loops)==1
                addplanesurface!(geo, loops[1])
            elseif length(loops)==2
                splitplanesurface!(geo, s, loops...)
            else
                error("too many loops")
            end
        else
            loops = findloops(l, inner=false)

            # add external surface
            for lo in loops
                addplanesurface!(geo, lo)
            end
        end
    end
end


function addarc!(geo::GeoModel, p1::Point, p2::Point, p3::Point; n=0, tag="")
    p1 = getpoint(geo, p1)
    p2 = getpoint(geo, p2)
    p3 = getpoint(geo, p3)

    arc = Arc(p1, p2, p3, n=n, tag=tag)
    aa = getline(geo, arc)
    aa===nothing || return aa

    # TODO: look for intersections

    # add arc
    geo._id +=1
    arc.id = geo._id
    push!(geo.lines, arc)

    push!(p1.lines, arc)
    push!(p3.lines, arc)

    loops = findloops(arc, inner=false)

    # add external surface
    for lo in loops
        addplanesurface!(geo, lo)
    end

    return arc
end


export addpath!

function addpath!(geo::GeoModel, path::Path)
    for cmd in path.cmds
        if cmd isa LineCmd
            addline!(geo, cmd.p1, cmd.p2)
        end
    end
end

addpath!(geo::GeoModel, args...; closed=false) = addpath!(geo, Path(args...; closed=closed))



export addsuppath!
function addsuppath!(geo::GeoModel, suppath::SupPath)
    push!(geo.supp_paths, suppath)
end

function addsuppath!(geo::GeoModel, args...; kwargs...) 
    addsuppath!(geo, SupPath(Path(args...); kwargs...))
end



function getpoints(lo::AbstractLoop)
    points = Point[]
    l1 = lo.lines[1]

    # get the first point
    if lo.lines[1].points[end] in lo.lines[2].points[[1,end]]
        push!(points, l1.points[end])
    else
        push!(points, l1.points[1])
    end

    # get remaining points
    for i in 2:length(lo.lines)
        l = lo.lines[i]
        if l.points[1] == points[end]
            push!(points, l.points[end])
        else
            push!(points, l.points[1])
        end
    end

    return points
end


function colinear(points::Vector{Point})
    length(points)<2 && return true
    tol = 1e-8
    
    X1 = points[1].coord
    X2 = points[2].coord
    X1X2 = X2-X1

    for p in points[3:end]
        X = p.coord
        X1X = X-X1
        N = cross(X1X2, X1X)
        if norm(N) > tol 
            return false
        end
    end
    
    return true
end


function getnormal(points::Vector{Point})
    length(points)<3 && return nothing
    tol = 1e-8
    
    X1 = points[1].coord
    X2 = points[2].coord
    X1X2 = X2-X1
    
    # find a plane looking for a non-colinear point
    local X, N, k
    for p in points[3:end]
        X = p.coord
        X1X = X-X1
        N = cross(X1X2, X1X)
        if norm(N) > tol 
            k = i+1 # index to start to check if points are in plane
            break
        end
    end
    
    # test the plane at each point
    for p in points[k:end]
        X = p.coord
        dot(X-X1, N) > tol && return nothing
    end

    return normalize(N)
end


function coplanar(points::Vector{Point})
    n = length(points)
    n<3 && return true

    tol = 1e-8
    
    # find a plane
    X1 = points[1].coord
    X2 = points[2].coord
    X1X2 = X2-X1

    # look for a non-colinear point
    local X, N, k
    for p in points[3:n]
        X = p.coord
        X1X = X-X1
        N = cross(X1X2, X1X)
        if norm(N) > tol 
            k = i+1 # index to start to check if points are in plane
            break
        end
    end
    
    # test the plane at each point
    for p in points[k:end]
        X = p.coord
        dot(X-X1, N) > tol && return false
    end

    return true
end


function coplanar(lo::Loop)
    return coplanar(getpoints(lo))
end


# loop points have to be coplanar
function getplane(lo::Loop)
    return getplane(getpoints(lo))
end


function windingnumber(polygon::Matrix{Float64}, x::Float64, y::Float64)
    n = size(polygon, 1)
    wn = 0
    for i in 1:n
        j = i%n + 1
        xi = polygon[i,1]
        xj = polygon[j,1]
        yi = polygon[i,2]
        yj = polygon[j,2]

        # check if the ray crossed line ij
        (x<=max(xi, xj) && min(yi,yj)<=y<=max(yi,yj)) || continue

        # finds if three points are in counter clock wise sequence
        ccw = (x - xi)*(yj - yi) < (y - yi)*(xj - xi)

        k = j%n + 1
        yk = polygon[k,2] # next y in case of intersection at the vertex

        if yi<y<yj && ccw
            wn += 1
        elseif yi>y>yj && !ccw
            wn -= 1
        elseif yi<yj<yk && yj==y && ccw
            wn += 1
        elseif yi>yj>yk && yj==y && !ccw
            wn -= 1
        end
    end

    # inside if winding is not zero
    return wn
end


# todo: improve centroid calculation
function insidepolygon(testpoints::Vector{Point}, points::Vector{Point}; tol=1e-8)
    coords = [ p.coord for p in points ]
    testcoords = [ p.coord for p in testpoints ]

    # Rotating points to the xy plane.
    Z = Vec3(0,0,1)
    P = Plane(points)
    N = P.normal
    θ    = acos(dot(N, Z))
    axis = cross(N, Z)
    if norm(axis)>1e-8
        axis = normalize(axis)
        R    = Quaternion(cos(θ/2), axis[1]*sin(θ/2), axis[2]*sin(θ/2), axis[3]*sin(θ/2))
        base = sum(p.coord for p in points)/length(points)
        coords = [ base + R*(p.coord-base)*conj(R) for p in points ]
        testcoords = [ base + R*(p.coord-base)*conj(R) for p in testpoints ]
    end

    polygon   = hcat(coords...)'[:,1:2]
    # check if all testpoins are in the same level as the plane from points
    for coord in testcoords
        abs(coord[3] - coords[1][3])>1e-8 && return false
    end

    # expand or shrink polygon according to tol
    center = mean(polygon, dims=1)
    polygon = center .+ (1+tol)*(polygon .- center)

    for coord in testcoords
        x, y, _ = coord
        windingnumber(polygon, x, y)==0 && return false # outside
    end

    return true
end


function insidepolygon(pt::Point, points::Array{Point,1}; tol=1e-8)
    return insidepolygon( [pt], points, tol=tol)
end


function inside(pt::Point, loop::PlaneLoop)
    points = getpoints(loop)
    return insidepolygon(pt, points, tol=-1e-8)
end


# check if loop1 is completely inside loop2
function inside(loop1::PlaneLoop, loop2::PlaneLoop)
    # check if loops are coplanar
    loop1.plane != loop2.plane && return false

    points1 = getpoints(loop1)
    points2 = getpoints(loop2)
    length(intersect(points1, points2))>0 && return false

    !insidepolygon(points1, points2, tol=-1e-8) && return false

    return true
end

function enclosed(loop1::PlaneLoop, loop2::PlaneLoop)
    loop1.plane != loop2.plane && return false

    points1 = getpoints(loop1)
    points2 = getpoints(loop2)
    testpoints = setdiff(points1, points2)
    length(testpoints)==0 && return true  # todo ???
    return insidepolygon(testpoints, points2, tol=1e-8)
end


function inside(pts::Vector{Point}, s::PlaneSurface)
    for p in pts
        !coplanar(s.plane, p) && return false
    end
    
    !insidepolygon(pts, getpoints(s.loops[1])) && return false

    for lo in s.loops[2:end]
        insidepolygon(pts, getpoints(lo), tol=-1e-8) && return false
    end

    return true
end

function addsingleplanesurface!(geo::GeoModel, loop::Loop; tag="")

    s1 = PlaneSurface(loop, tag=tag)
    s = getsurface(geo, s1)
    s === nothing || return s

    # add new loop and surface
    loop = addsingleloop!(geo, loop)
    geo._id +=1
    s1.id = geo._id
    push!(geo.surfaces, s1)

    # update edges
    for lo in s1.loops
        for l in lo.lines
            push!(l.surfaces, s1)
        end
    end

    # todo: add and update volumes

    return s1
end


function addplanesurface!(geo::GeoModel, loop::PlaneLoop; tag="")

    s1 = PlaneSurface(loop, tag=tag)
    s = getsurface(geo, s1)
    s === nothing || return s

    # check if loop encloses other loops and shares any side (overlapping)
    for s in geo.surfaces
        s isa PlaneSurface || continue
        s1.plane==s.plane || continue
        length(intersect(loop.lines, s.loops[1].lines))>0 && enclosed(s.loops[1], loop) && return nothing
    end

    # add new loop and surface
    loop = addsingleloop!(geo, loop)
    geo._id +=1
    s1.id = geo._id
    push!(geo.surfaces, s1)

    # check if loop is inside other surfaces (set as hole) # todo: improve for hole inside hole
    for s in geo.surfaces
        s isa PlaneSurface || continue
        loop.id==s.loops[1].id && continue
        if inside(loop, s.loops[1]) 
            push!(s.loops, loop)
            for v in s.volumes
                push!(v.surfaces, s1)
                push!(s1.volumes, v)
            end
        end
    end

    # check if loop encloses other loops (set holes) # todo: improve for hole inside hole
    for s in geo.surfaces
        s isa PlaneSurface || continue
        loop.id==s.loops[1].id && continue
        inside(s.loops[1], loop) && push!(s1.loops, s.loops[1])
    end

    # update edges
    for lo in s1.loops
        for l in lo.lines
            push!(l.surfaces, s1)
        end
    end

    # todo: add and update volumes

    return s1
end

function addsurface!(geo::GeoModel, loop::Loop; tag="")

    s1 = Surface(loop, tag=tag)
    s = getsurface(geo, s1)
    s === nothing || return s

    # add new loop and surface
    loop = addsingleloop!(geo, loop)
    geo._id +=1
    s1.id = geo._id
    push!(geo.surfaces, s1)

    # update edges
    for lo in s1.loops
        for l in lo.lines
            push!(l.surfaces, s1)
        end
    end

    # todo: add and update volumes

    return s1
end


function splitplanesurface!(geo::GeoModel, s::PlaneSurface, loop1::PlaneLoop, loop2::PlaneLoop)
    # add new loop
    loop1 = addsingleloop!(geo, loop1)
    s1 = PlaneSurface(loop1)
    s1.tag = s.tag

    # add surface
    geo._id +=1
    s1.id = geo._id
    push!(geo.surfaces, s1)

    # remove references to s and holes in its lines
    for lo in s.loops
        for l in lo.lines
            filter!(!=(s), l.surfaces)
        end
    end
    
    # update outer loop in s with loop2
    s.loops[1].lines = loop2.lines

    # update holes in s1 and s
    holeloops = s.loops[2:end]
    s1.loops = [ s1.loops[1]; [ lo for lo in holeloops if inside(lo, s1.loops[1]) ] ]
    s.loops = [ s.loops[1]; [ lo for lo in holeloops if inside(lo, s.loops[1]) ] ]

    # update references to surfaces in edges
    for su in [s1, s]
        for lo in su.loops
            for l in lo.lines
                push!(l.surfaces, su)
            end
        end
    end

    # update volumes
    append!(s1.volumes, s.volumes)
    for v in s.volumes
        push!(v.surfaces, s1)
    end

    return s1
end


function addvolume!(geo::GeoModel, surfaces::Array{<:AbstractSurface,1}; tag="")
    v = Volume(surfaces, tag=tag)
    vv = getvolume(geo, v)
    vv===nothing || return v

    geo._id +=1
    v.id = geo._id
    push!(geo.volumes, v)

    return v
end

export extrude!


function extrude!(geo::GeoModel, line::Line; axis=[0.,0,1], length=1.0)
    p1, p2 = line.points
    dx = length*axis[1]
    dy = length*axis[2]
    dz = length*axis[3]
    p3 = copy!(geo, p2, dx=dx, dy=dy, dz=dz)
    p4 = copy!(geo, p1, dx=dx, dy=dy, dz=dz)
    l1 = addsingleline!(geo, p1, p2, tag=line.tag)
    l2 = addsingleline!(geo, p2, p3, tag=line.tag)
    l3 = addsingleline!(geo, p3, p4, tag=line.tag)
    l4 = addsingleline!(geo, p4, p1, tag=line.tag)

    lo = PlaneLoop(l1, l2, l3, l4)
    s = addplanesurface!(geo, lo)

    @assert s!==nothing
    return s
end


function extrude!(geo::GeoModel, arc::Arc; axis=[0,0,1], length=1.0)
    p1, p2, p3 = arc.points
    dx = length*axis[1]
    dy = length*axis[2]
    dz = length*axis[3]
    p4 = copy!(geo, p3, dx=dx, dy=dy, dz=dz)
    p5 = copy!(geo, p2, dx=dx, dy=dy, dz=dz)
    p6 = copy!(geo, p1, dx=dx, dy=dy, dz=dz)

    c1 = addsinglearc!(geo, p1, p2, p3, tag=arc.tag)
    c2 = addsingleline!(geo, p3, p4, tag=arc.tag)
    c3 = addsinglearc!(geo, p4, p5, p6, tag=arc.tag)
    c4 = addsingleline!(geo, p6, p1, tag=arc.tag)

    lo = Loop(c1, c2, c3, c4)

    geo._id +=1
    lo.id = geo._id
    push!(geo.loops, lo)

    s = addsurface!(geo, lo)
    return s
end


function extrude!(geo::GeoModel, surf::PlaneSurface; axis=[0.,0,1], length=1.0)

    # check if surf is an inner surface
    # innersurf = nothing
    # for s in geo.surfaces
    #     for lo in s.loops[2:end]
    #         if lo==surf.loop
    #             innersurf=s
    #             break
    #         end
    #     end
    # end

    surfs = AbstractSurface[]

    # extrude lateral lines
    for lo in surf.loops
        for line in lo.lines
            s = extrude!(geo, line, axis=axis, length=length)
            s.tag = surf.tag
            push!(surfs, s)
        end
    end

    # find lid loops (outer and inner loops if existent)
    loops = PlaneLoop[]
    for lo in surf.loops
        lines = AbstractLine[]
        for line in lo.lines

            points = Point[]
            for p in line.points
                pp = Point(p.coord .+ length.*axis)
                pp = getpoint(geo, pp) # point should exists
                push!(points, pp)
            end

            if Base.length(points)==2
                l = getline(geo, Line(points...))
            else
                l = getline(geo, Arc(points...))
            end
            push!(lines, l)
        end
        lo = PlaneLoop(lines...)
        push!(loops, lo)
    end

    # add single loops
    for lo in loops
        geo._id +=1
        lo.id = geo._id
        push!(geo.loops, lo)
    end

    # add closing lid
    for lo in loops
        s = addplanesurface!(geo, lo, tag=surf.tag)
        push!(surfs, s)
    end

    # check if surf is part of a volume
    volume = nothing
    for v in geo.volumes
        if surf in v.surfaces
            volume = v
            break
        end
    end

    if volume===nothing
        push!(surfs, surf)
        volume = addvolume!(geo, surfs, tag=surf.tag)
    else
        # remove surf from geo
        filter!(!=(surf), geo.surfaces)
        
        # remove surf from volume
        filter!(!=(surf), volume.surfaces)
        
        # remove unused surface loops from geo
        for lo in surf.loops
            # for each curve remove links to this surface
            for l in lo.lines
                filter!(!=(surf), l.surfaces)
            end 
        end

        # add new surfaces to volume
        for s in surfs
            push!(volume.surfaces, s)
        end
    end

    for s in surfs
        push!(s.volumes, volume)
    end

    return volume
end


function extrude!(geo::GeoModel, surfs::Vector{<:AbstractSurface}; axis=[0.,0,1], length=1.0)
    surfs = copy(surfs) # make a copy
    for s in surfs
        extrude!(geo, s; axis=axis, length=length)
    end
end


function extrude!(m::GeoModel; nargs...)
    extrude!(m, m.surfaces; nargs...)
end


function pull!(m::GeoModel, surf::AbstractSurface; axis=[0.,0,1], length=1.0)
    
end


export picksurface

function picksurface(geo::GeoModel, p::Point)
    return picksurface(geo, p.coord...)
end


function picksurface(geo::GeoModel, x::Real, y::Real, z::Real=0.0)
    p = Point(x, y, z)
    for s in geo.surfaces
        isin = inside(p, s.loops[1])
        if isin && length(s.loops)>=2
            for lo in s.loops[2:end]
                if inside(p, lo)
                    isin = false
                    break
                end
            end
        end
        isin && return s
    end
    return nothing
end


function tag!(s::AbstractSurface, tag::String)
    s.tag = tag
end
