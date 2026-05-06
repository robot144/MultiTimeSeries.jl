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

"""
    scatter(obs, model; location_index=1, kwargs...) -> Plots.Plot

Scatter plot of `model` versus `obs` for one location, with a 1:1 reference line.
Time steps where either series contains `NaN` are excluded.

# Keyword arguments (in addition to all standard Plots.jl kwargs)
- `location_index`: which location to plot (default `1`).
- `unit`: string appended to both axis labels (default `""`).
"""
function Plots.scatter(obs::AbstractTimeSeries, model::AbstractTimeSeries;
                       location_index::Integer = 1,
                       unit::String = "",
                       kwargs...)
    obs_names = get_names(obs)
    if location_index ∉ eachindex(obs_names)
        error("location_index $location_index is out of range " *
              "($(length(obs_names)) location(s) available).")
    end

    obs_vals   = Float64.(get_values(obs)[location_index, :])
    model_vals = Float64.(get_values(model)[location_index, :])

    valid      = .!isnan.(obs_vals) .& .!isnan.(model_vals)
    obs_vals   = obs_vals[valid]
    model_vals = model_vals[valid]

    qty    = get_quantity(obs)
    axlbl  = isempty(unit) ? qty : "$qty ($unit)"
    lim    = extrema(vcat(obs_vals, model_vals))
    margin = 0.05 * (lim[2] - lim[1])
    lim    = (lim[1] - margin, lim[2] + margin)

    p = Plots.scatter(obs_vals, model_vals;
        label         = obs_names[location_index],
        xlabel        = "Observed $axlbl",
        ylabel        = "Modelled $axlbl",
        title         = get_source(obs),
        legend        = :outertopright,
        bottom_margin = 5mm,
        left_margin   = 5mm,
        xlims         = lim,
        ylims         = lim,
        aspect_ratio  = :equal,
        kwargs...,
    )
    Plots.plot!(p, collect(lim), collect(lim);
        label     = "1:1",
        color     = :black,
        linestyle = :dash,
    )
    return p
end
