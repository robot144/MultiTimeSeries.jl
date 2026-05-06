# plotting.jl
#
# Plots.jl methods for AbstractTimeSeries.
#
# Returns a `Plots.Plot` and accepts any keyword arguments that Plots.jl
# itself accepts (title, size, dpi, …).

import Plots
import Plots: mm

"""
    plot(ts::AbstractTimeSeries; location_index=1, kwargs...) -> Plots.Plot

Line plot of one location in `ts` versus time.

# Keyword arguments (in addition to all standard Plots.jl kwargs)
- `location_index`: which location to plot (default `1`).
- `yunit`: string appended to the y-axis label (default `""`).
"""
function Plots.plot(ts::AbstractTimeSeries;
                    location_index::Integer = 1,
                    label = nothing,
                    yunit::String = "",
                    kwargs...)
    times  = get_times(ts)
    vals   = get_values(ts)
    names  = get_names(ts)
    qty    = get_quantity(ts)

    if location_index ∉ eachindex(names)
        error("location_index $location_index is out of range " *
              "($(length(names)) location(s) available).")
    end

    ylabel = isempty(yunit) ? qty : "$qty ($yunit)"
    lbl    = isnothing(label) ? names[location_index] : label

    return Plots.plot(times, vals[location_index, :];
        label         = lbl,
        xlabel        = "Time",
        ylabel        = ylabel,
        title         = get_source(ts),
        legend        = :outertopright,
        bottom_margin = 5mm,
        left_margin   = 5mm,
        kwargs...,
    )
end
