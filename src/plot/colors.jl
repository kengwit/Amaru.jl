# This file is part of Amaru package. See copyright license in https://github.com/NumSoftware/Amaru

const _default_colors = [ :c1, :c2, :c3, :c4, :c5, :c6, :c7, :c8, :c9, :c10, :c11, :c12, :c13, :c14, :c15, :c16, ]

_colors_dict = Dict(
    :c1          => (0.769, 0.306, 0.322), # red
    :c2          => (0.333, 0.659, 0.408), # green
    :c3          => (0.298, 0.447, 0.690), # blue
    :c4          => (0.867, 0.522, 0.322), # orange
    :c5          => (0.506, 0.447, 0.702), # purple
    :c6          => (0.000, 0.667, 0.682).*0.9, # aquamarine
    :c7          => (0.576, 0.471, 0.376),
    :c8          => (0.647, 0.318, 0.580),
    # :C1          => (0.0,0.605,0.978),
    # :C2          => (0.888,0.435,0.278),
    # :C3          => (0.242,0.643,0.304),
    # :C4          => (0.764,0.444,0.824),
    # :C5          => (0.675,0.555,0.094),
    # :C6          => (0.0,0.66575,0.68099),
    # :C7          => (0.930,0.36747,0.575),
    # :C8          => (0.776,0.50974,0.146),
    # :C9          => (0.0,0.66426,0.55295),
    # :C10         => (0.558,0.593,0.117),
    # :C11         => (0.0,0.66087,0.79817),
    # :C12         => (0.609,0.499,0.911),
    # :C13         => (0.380,0.551,0.966),
    # :C14         => (0.942,0.375,0.451),
    # :C15         => (0.868,0.395,0.713),
    # :C16         => (0.423,0.622,0.198),
    :aliceblue   => (0.941, 0.973, 1.0),
    :blue        => (0.0, 0.0, 1.0),
    :black       => (0.0, 0.0, 0.0),
    :brown       => (0.647, 0.165, 0.165),
    :cadetblue   => (0.373, 0.62, 0.627),
    :cyan        => (0.0, 1.0, 1.0),
    :darkblue    => (0.0, 0.0, 0.545),
    :darkgreen   => (0.0, 0.392, 0.0),
    :darkmagenta => (0.545, 0.0, 0.545),
    :darkgray    => (0.663, 0.663, 0.663),
    :darkorange  => (1.0, 0.549, 0.0),
    :darkred     => (0.545, 0.0, 0.0),
    :darkcyan    => (0.0, 0.545, 0.545),
    :gray        => (0.502, 0.502, 0.502),
    :green       => (0.0, 0.502, 0.0),
    :grey        => (0.502, 0.502, 0.502),
    :indianred   => (0.804, 0.361, 0.361),
    :indigo      => (0.294, 0.0, 0.51),
    :lightblue   => (0.678, 0.847, 0.902),
    :lightgreen  => (0.565, 0.933, 0.565),
    :magenta     => (1.0, 0.0, 1.0),
    :olive       => (0.502, 0.502, 0.0),
    :orange      => (1.0, 0.647, 0.0),
    :pink        => (1.0, 0.753, 0.796),
    :purple      => (0.502, 0.0, 0.502),
    :red         => (1.0, 0.0, 0.0),
    :royalblue   => (0.255, 0.412, 0.882),
    :steelblue   => (0.275, 0.51, 0.706),
    :violet      => (0.933, 0.51, 0.933),
    :white       => (1.0, 1.0, 1.0),
    :yellow      => (1.0, 1.0, 0.0),
)

_colors_list = collect(keys(_colors_dict))


function get_color(color::Tuple, default=:black)
    return color
end

function get_color(color::Symbol, default=:black)
    if color==:default
        if default isa Symbol
            color = default
        else
            return default
        end
    end

    color in keys(_colors_dict) || throw(AmaruException("get_color: color must be one of $_colors_list. Got $color"))
    return _colors_dict[color]
end


struct Colormap
    stops::Vector{Float64}
    colors::Array{Vec3}

    function Colormap(stops, colors)
        @assert length(stops)==length(colors)
        # @assert stops[1]==0.0
        # @assert stops[end]==1.0
        return new(stops, colors)
    end
end

function Colormap(name::Symbol; limits=Float64[], rev=false)
    name in _colormaps_list || throw(AmaruException("Colormap: colormap not found which must be one of $(_colormaps_list)"))
    colormap = _colormaps_dict[name]

    length(limits)==2 && (colormap = clip_colormap(colormap, limits))
    rev && (colormap = reverse(colormap))

    return colormap
end

# Interpolate a color
function (cmap::Colormap)(rval)
    rval<=cmap.stops[1] && return cmap.colors[1]
    rval>=cmap.stops[end] && return cmap.colors[end]
    idx = findfirst(>(rval), cmap.stops)

    t = (rval-cmap.stops[idx-1])/(cmap.stops[idx]-cmap.stops[idx-1])
    return (1-t)*cmap.colors[idx-1] + t*cmap.colors[idx]
end

function resize(cmap::Colormap, min, max; divergefromzero=false)
    rmin = cmap.stops[1]
    rmax = cmap.stops[end]

    (min>=0 || max<=0) && (divergefromzero=false)

    if divergefromzero
        rmid = 0.5*(rmax-rmin)

        stops = []
        for rval in cmap.stops
            if rval<rmid
                s = min - min*(rval-rmin)/(rmid-rmin)
            else
                s = max*(rval-rmid)/(rmax-rmid)
            end
            push!(stops, s)
        end
    else
        stops = [ min + (rval-rmin)/(rmax-rmin)*(max-min) for rval in cmap.stops ]
    end

    return Colormap(stops, cmap.colors)
end

function Base.reverse(cmap::Colormap)
    stops = [ round(1-stop, digits=3) for stop in reverse(cmap.stops) ]
    colors = reverse(cmap.colors)
    return Colormap(stops, colors)
end

function clip_colormap(cmap::Colormap, limits=Float64[])
    n = 21
    minstop, maxstop = extrema(cmap.stops)
    @assert limits[1]>=minstop && limits[2]<=maxstop
    minstop, maxstop = limits
    stops = [ x for x in range(minstop, maxstop, n) ]
    colors = [ cmap(x) for x in range(minstop,maxstop,n) ]
    return Colormap(stops, colors)
end



_colormaps_dict = Dict(
    :bone => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.000, 0.000, 0.000), (0.045, 0.045, 0.062), (0.089, 0.089, 0.124), (0.130, 0.130, 0.181), (0.175, 0.175, 0.243), (0.220, 0.220, 0.306), (0.261, 0.261, 0.363), (0.305, 0.305, 0.425), (0.350, 0.361, 0.475), (0.395, 0.423, 0.520), (0.439, 0.484, 0.564), (0.480, 0.541, 0.605), (0.525, 0.602, 0.650), (0.570, 0.663, 0.695), (0.611, 0.720, 0.736), (0.657, 0.780, 0.780), (0.727, 0.825, 0.825), (0.796, 0.870, 0.870), (0.866, 0.914, 0.914), (0.930, 0.955, 0.955), (1.000, 1.000, 1.000), ]
    ),
    :inferno => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.001, 0.000, 0.014), (0.029, 0.022, 0.115), (0.093, 0.046, 0.234), (0.170, 0.042, 0.341), (0.258, 0.039, 0.406), (0.342, 0.062, 0.429), (0.416, 0.090, 0.433), (0.497, 0.119, 0.424), (0.578, 0.148, 0.404), (0.658, 0.179, 0.373), (0.736, 0.216, 0.330), (0.802, 0.259, 0.283), (0.865, 0.317, 0.226), (0.916, 0.387, 0.165), (0.952, 0.462, 0.105), (0.977, 0.551, 0.039), (0.988, 0.645, 0.040), (0.983, 0.744, 0.138), (0.964, 0.844, 0.273), (0.946, 0.931, 0.442), (0.988, 0.998, 0.645), ]
    ),
    :coolwarm => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.230, 0.299, 0.754), (0.290, 0.387, 0.829), (0.353, 0.472, 0.893), (0.415, 0.547, 0.939), (0.484, 0.622, 0.975), (0.554, 0.690, 0.996), (0.619, 0.744, 0.999), (0.688, 0.793, 0.988), (0.754, 0.830, 0.961), (0.814, 0.854, 0.918), (0.867, 0.864, 0.863), (0.913, 0.837, 0.795), (0.947, 0.795, 0.717), (0.966, 0.740, 0.637), (0.969, 0.679, 0.563), (0.958, 0.604, 0.483), (0.932, 0.519, 0.406), (0.892, 0.425, 0.333), (0.839, 0.322, 0.265), (0.780, 0.210, 0.207), (0.706, 0.016, 0.150), ]
    ),
    :spectral => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.620, 0.004, 0.259), (0.730, 0.126, 0.285), (0.838, 0.247, 0.309), (0.895, 0.333, 0.287), (0.957, 0.427, 0.263), (0.975, 0.557, 0.323), (0.991, 0.677, 0.378), (0.994, 0.778, 0.461), (0.996, 0.878, 0.545), (0.998, 0.940, 0.649), (0.998, 0.999, 0.746), (0.952, 0.981, 0.674), (0.902, 0.961, 0.596), (0.784, 0.913, 0.620), (0.675, 0.869, 0.642), (0.538, 0.815, 0.645), (0.400, 0.761, 0.647), (0.296, 0.645, 0.695), (0.199, 0.529, 0.739), (0.281, 0.424, 0.689), (0.369, 0.310, 0.635), ]
    ),
    :seismic => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.000, 0.000, 0.300), (0.000, 0.000, 0.443), (0.000, 0.000, 0.585), (0.000, 0.000, 0.717), (0.000, 0.000, 0.860), (0.004, 0.004, 1.000), (0.192, 0.192, 1.000), (0.396, 0.396, 1.000), (0.600, 0.600, 1.000), (0.804, 0.804, 1.000), (1.000, 0.992, 0.992), (1.000, 0.804, 0.804), (1.000, 0.600, 0.600), (1.000, 0.396, 0.396), (1.000, 0.208, 0.208), (1.000, 0.004, 0.004), (0.900, 0.000, 0.000), (0.798, 0.000, 0.000), (0.696, 0.000, 0.000), (0.602, 0.000, 0.000), (0.500, 0.000, 0.000), ]
    ),
    :bwr => Colormap(
        [0.000, 0.050, 0.100, 0.150, 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500, 0.550, 0.600, 0.650, 0.700, 0.750, 0.800, 0.850, 0.900, 0.950, 1.000, ],
        [(0.000, 0.000, 1.000), (0.102, 0.102, 1.000), (0.204, 0.204, 1.000), (0.298, 0.298, 1.000), (0.400, 0.400, 1.000), (0.502, 0.502, 1.000), (0.596, 0.596, 1.000), (0.698, 0.698, 1.000), (0.800, 0.800, 1.000), (0.902, 0.902, 1.000), (1.000, 0.996, 0.996), (1.000, 0.902, 0.902), (1.000, 0.800, 0.800), (1.000, 0.698, 0.698), (1.000, 0.604, 0.604), (1.000, 0.502, 0.502), (1.000, 0.400, 0.400), (1.000, 0.298, 0.298), (1.000, 0.196, 0.196), (1.000, 0.102, 0.102), (1.000, 0.000, 0.000), ]
    ),
    :rainbown => Colormap(
        [0.000, 0.025, 0.050, 0.075, 0.100, 0.125, 0.150, 0.175, 0.200, 0.225, 0.250, 0.275, 0.300, 0.325, 0.350, 0.375, 0.400, 0.425, 0.450, 0.475, 0.500, 0.525, 0.550, 0.575, 0.600, 0.625, 0.650, 0.675, 0.700, 0.725, 0.750, 0.775, 0.800, 0.825, 0.850, 0.875, 0.900, 0.925, 0.950, 0.975, 1.000, ],
        [(0.500, 0.000, 1.000), (0.453, 0.074, 0.999), (0.398, 0.159, 0.997), (0.351, 0.232, 0.993), (0.296, 0.315, 0.987), (0.249, 0.384, 0.981), (0.202, 0.451, 0.973), (0.147, 0.526, 0.962), (0.100, 0.588, 0.951), (0.053, 0.646, 0.939), (0.002, 0.709, 0.923), (0.049, 0.759, 0.908), (0.096, 0.805, 0.892), (0.151, 0.853, 0.872), (0.198, 0.890, 0.853), (0.253, 0.926, 0.830), (0.300, 0.951, 0.809), (0.347, 0.971, 0.787), (0.402, 0.988, 0.759), (0.449, 0.997, 0.735), (0.504, 1.000, 0.705), (0.551, 0.997, 0.678), (0.598, 0.988, 0.651), (0.653, 0.971, 0.617), (0.700, 0.951, 0.588), (0.747, 0.926, 0.557), (0.802, 0.890, 0.521), (0.849, 0.853, 0.489), (0.896, 0.813, 0.457), (0.951, 0.759, 0.418), (0.998, 0.709, 0.384), (1.000, 0.646, 0.344), (1.000, 0.588, 0.309), (1.000, 0.526, 0.274), (1.000, 0.451, 0.232), (1.000, 0.384, 0.196), (1.000, 0.303, 0.153), (1.000, 0.232, 0.117), (1.000, 0.159, 0.080), (1.000, 0.074, 0.037), (1.000, 0.000, 0.000), ]
    ),
    :jet => Colormap(
        [0.000, 0.025, 0.050, 0.075, 0.100, 0.125, 0.150, 0.175, 0.200, 0.225, 0.250, 0.275, 0.300, 0.325, 0.350, 0.375, 0.400, 0.425, 0.450, 0.475, 0.500, 0.525, 0.550, 0.575, 0.600, 0.625, 0.650, 0.675, 0.700, 0.725, 0.750, 0.775, 0.800, 0.825, 0.850, 0.875, 0.900, 0.925, 0.950, 0.975, 1.000, ],
        [(0.000, 0.000, 0.500), (0.000, 0.000, 0.607), (0.000, 0.000, 0.732), (0.000, 0.000, 0.839), (0.000, 0.000, 0.963), (0.000, 0.002, 1.000), (0.000, 0.096, 1.000), (0.000, 0.206, 1.000), (0.000, 0.300, 1.000), (0.000, 0.394, 1.000), (0.000, 0.504, 1.000), (0.000, 0.598, 1.000), (0.000, 0.692, 1.000), (0.000, 0.802, 1.000), (0.000, 0.896, 0.971), (0.085, 1.000, 0.882), (0.161, 1.000, 0.806), (0.237, 1.000, 0.731), (0.326, 1.000, 0.642), (0.402, 1.000, 0.566), (0.490, 1.000, 0.478), (0.566, 1.000, 0.402), (0.642, 1.000, 0.326), (0.731, 1.000, 0.237), (0.806, 1.000, 0.161), (0.882, 1.000, 0.085), (0.971, 0.959, 0.000), (1.000, 0.872, 0.000), (1.000, 0.785, 0.000), (1.000, 0.683, 0.000), (1.000, 0.596, 0.000), (1.000, 0.495, 0.000), (1.000, 0.407, 0.000), (1.000, 0.320, 0.000), (1.000, 0.219, 0.000), (1.000, 0.131, 0.000), (0.946, 0.030, 0.000), (0.839, 0.000, 0.000), (0.732, 0.000, 0.000), (0.607, 0.000, 0.000), (0.500, 0.000, 0.000), ]
    ),
    :turbo => Colormap(
        [0.000, 0.025, 0.050, 0.075, 0.100, 0.125, 0.150, 0.175, 0.200, 0.225, 0.250, 0.275, 0.300, 0.325, 0.350, 0.375, 0.400, 0.425, 0.450, 0.475, 0.500, 0.525, 0.550, 0.575, 0.600, 0.625, 0.650, 0.675, 0.700, 0.725, 0.750, 0.775, 0.800, 0.825, 0.850, 0.875, 0.900, 0.925, 0.950, 0.975, 1.000, ],
        [(0.190, 0.072, 0.232), (0.217, 0.141, 0.400), (0.242, 0.219, 0.569), (0.259, 0.285, 0.693), (0.271, 0.359, 0.812), (0.276, 0.421, 0.891), (0.276, 0.481, 0.951), (0.269, 0.550, 0.993), (0.244, 0.609, 0.997), (0.207, 0.669, 0.974), (0.158, 0.736, 0.923), (0.122, 0.789, 0.866), (0.098, 0.837, 0.803), (0.097, 0.885, 0.733), (0.127, 0.917, 0.676), (0.197, 0.949, 0.595), (0.276, 0.971, 0.517), (0.366, 0.987, 0.437), (0.474, 0.998, 0.350), (0.560, 0.999, 0.286), (0.644, 0.990, 0.234), (0.706, 0.973, 0.210), (0.766, 0.946, 0.203), (0.832, 0.906, 0.208), (0.883, 0.866, 0.217), (0.927, 0.820, 0.226), (0.965, 0.764, 0.228), (0.985, 0.713, 0.216), (0.995, 0.653, 0.196), (0.995, 0.575, 0.164), (0.986, 0.505, 0.134), (0.966, 0.422, 0.098), (0.941, 0.356, 0.070), (0.910, 0.296, 0.048), (0.868, 0.237, 0.031), (0.824, 0.192, 0.020), (0.765, 0.144, 0.010), (0.707, 0.107, 0.006), (0.642, 0.074, 0.004), (0.559, 0.040, 0.006), (0.480, 0.016, 0.011), ]
    ),
)
 
_colormaps_list = collect(keys(_colormaps_dict))