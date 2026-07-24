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

# ── shared helpers ────────────────────────────────────────────────────────────

# Extract one location's obs/model values as Float64, dropping time steps where
# either series is NaN. Errors on an out-of-range location_index.
function _paired_valid_values(obs::AbstractTimeSeries, model::AbstractTimeSeries,
                              location_index::Integer)
    names = get_names(obs)
    if location_index ∉ eachindex(names)
        error("location_index $location_index is out of range " *
              "($(length(names)) location(s) available).")
    end
    obs_vals   = Float64.(get_values(obs)[location_index, :])
    model_vals = Float64.(get_values(model)[location_index, :])
    valid      = .!isnan.(obs_vals) .& .!isnan.(model_vals)
    return obs_vals[valid], model_vals[valid]
end

# Shared square x/y limits (common range) with a 5% margin.
function _square_limits(x, y)
    lo, hi = extrema(vcat(x, y))
    margin = hi > lo ? 0.05 * (hi - lo) : 1.0
    return (lo - margin, hi + margin)
end

# 2D histogram of (x, y) on an nbins×nbins grid over `lim`. Returns the bin
# centres, a `log10(count)` matrix with empty bins set to `NaN` (rendered blank),
# the raw count matrix, and each point's (ix, iy) bin indices.
function _log_count_grid(x, y, lim, nbins)
    edges   = range(lim[1], lim[2]; length = nbins + 1)
    centers = (edges[1:end-1] .+ edges[2:end]) ./ 2
    C  = zeros(Float64, nbins, nbins)          # C[iy, ix]
    ix = Vector{Int}(undef, length(x))
    iy = Vector{Int}(undef, length(x))
    @inbounds for k in eachindex(x)
        ix[k] = clamp(searchsortedlast(edges, x[k]), 1, nbins)
        iy[k] = clamp(searchsortedlast(edges, y[k]), 1, nbins)
        C[iy[k], ix[k]] += 1
    end
    Z = log10.(C)
    Z[C .== 0] .= NaN
    return centers, Z, C, ix, iy
end

"""
    scatter(obs, model; location_index=1, unit="", density=:auto, nbins=200, kwargs...) -> Plots.Plot

Predicted-vs-observed plot for one location, with a dashed 1:1 reference line and
equal aspect ratio. Time steps where either series contains `NaN` are excluded.

`density` controls how the point cloud is drawn, so it stays readable when there
are many points:
- `:auto` (default): transparent points when ≤ 10 000 valid pairs, otherwise a
  `log10(count)` density heatmap.
- `:points`: transparent scatter; marker alpha adapts to the point count.
- `:heatmap`: 2D `log10(count)` density heatmap (`:viridis`, empty bins blank).
- `:density_points`: scatter with each point coloured by its local density
  (opt-in; renders every marker, so slow for very large N).

# Keyword arguments (in addition to all standard Plots.jl kwargs)
- `location_index`: which location to plot (default `1`).
- `unit`: string appended to both axis labels (default `""`).
- `density`: `:auto` | `:points` | `:heatmap` | `:density_points`.
- `nbins`: grid resolution for the density modes (default `200`).
"""
function Plots.scatter(obs::AbstractTimeSeries, model::AbstractTimeSeries;
                       location_index::Integer = 1,
                       unit::String = "",
                       density::Symbol = :auto,
                       nbins::Integer = 200,
                       kwargs...)
    x, y = _paired_valid_values(obs, model, location_index)
    isempty(x) && error("scatter: no valid (non-NaN) overlapping values.")

    qty    = get_quantity(obs)
    axlbl  = isempty(unit) ? qty : "$qty ($unit)"
    lim    = _square_limits(x, y)

    mode = density === :auto ? (length(x) > 10_000 ? :heatmap : :points) : density

    common = (xlabel = "Observed $axlbl", ylabel = "Modelled $axlbl",
              title = get_source(obs), xlims = lim, ylims = lim,
              aspect_ratio = :equal, legend = :bottomright,
              bottom_margin = 5mm, left_margin = 5mm)

    if mode === :points
        alpha = clamp(3000 / length(x), 0.04, 1.0)
        ms    = length(x) > 2000 ? 2 : 4
        p = Plots.scatter(x, y; label = get_names(obs)[location_index],
            markersize = ms, markeralpha = alpha, markerstrokewidth = 0,
            common..., kwargs...)
    elseif mode === :heatmap
        centers, Z, _ = _log_count_grid(x, y, lim, nbins)
        p = Plots.heatmap(centers, centers, Z; color = :viridis,
            colorbar_title = "log10(count)", common..., kwargs...)
    elseif mode === :density_points
        centers, _, C, ix, iy = _log_count_grid(x, y, lim, nbins)
        dens  = [C[iy[k], ix[k]] for k in eachindex(x)]
        order = sortperm(dens; rev = true)          # sparse points drawn last
        p = Plots.scatter(x[order], y[order]; marker_z = log10.(dens[order]),
            label = "", color = :viridis, colorbar_title = "log10(local count)",
            markersize = 2, markerstrokewidth = 0, common..., kwargs...)
    else
        error("scatter: unknown density mode $(repr(density)); " *
              "use :auto, :points, :heatmap or :density_points.")
    end

    Plots.plot!(p, collect(lim), collect(lim);
        label = "1:1", color = :black, linestyle = :dash)
    return p
end

"""
    linear_fit!(p, obs, model; location_index=1, stats=true, color=:orange) -> (; slope, offset, r, bias)

Overlay a least-squares fit `model ≈ slope·obs + offset` on an existing
predicted-vs-observed plot `p`. When `stats`, add a top-left annotation with the
correlation `r`, `slope`, `offset` and `bias` (mean error, `mean(model - obs)`).
Returns those four statistics. NaN pairs are excluded.
"""
function linear_fit!(p::Plots.Plot, obs::AbstractTimeSeries, model::AbstractTimeSeries;
                     location_index::Integer = 1, stats::Bool = true, color = :orange)
    x, y = _paired_valid_values(obs, model, location_index)
    length(x) ≥ 2 || error("linear_fit!: need at least 2 valid (non-NaN) pairs.")
    var(x) > 0    || error("linear_fit!: observed values are constant; slope undefined.")

    slope  = cov(x, y) / var(x)
    offset = mean(y) - slope * mean(x)
    r      = cor(x, y)
    bias   = mean(y .- x)

    lim = _square_limits(x, y)
    Plots.plot!(p, collect(lim), slope .* collect(lim) .+ offset;
        label = "fit", color = color, linewidth = 2)

    if stats
        str = @sprintf("r = %.3f\nslope = %.3f\noffset = %.3f\nbias = %.3f",
                       r, slope, offset, bias)
        ax = lim[1] + 0.04 * (lim[2] - lim[1])
        ay = lim[2] - 0.04 * (lim[2] - lim[1])
        Plots.annotate!(p, ax, ay, Plots.text(str, :left, :top, 8))
    end
    return (; slope, offset, r, bias)
end

"""
    qq!(p, obs, model; location_index=1, probs=[0.01,0.10,0.50,0.90,0.99], unit="", color=:purple, dotcolor=:orange) -> (; probs, qx, qy)

Draw a quantile-quantile curve `sort(obs)` vs `sort(model)` on plot `p`, with a
dashed 1:1 line and percentile dots labelled inline `pct: obs→pred`. Sets equal
aspect, square limits and quantile axis labels, so it can be drawn onto a fresh
`Plots.plot()`. Compares the marginal distributions (unpaired), unlike the paired
`scatter`. Returns the percentile probabilities and their observed/modelled
quantiles. NaN pairs are excluded.
"""
function qq!(p::Plots.Plot, obs::AbstractTimeSeries, model::AbstractTimeSeries;
             location_index::Integer = 1,
             probs = [0.01, 0.10, 0.50, 0.90, 0.99],
             unit::String = "",
             color = :purple, dotcolor = :orange)
    x, y = _paired_valid_values(obs, model, location_index)
    isempty(x) && error("qq!: no valid (non-NaN) pairs.")

    qty   = get_quantity(obs)
    axlbl = isempty(unit) ? qty : "$qty ($unit)"
    lim   = _square_limits(x, y)

    Plots.plot!(p, sort(x), sort(y); label = "Q-Q", color = color, linewidth = 2,
        xlabel = "Observed $axlbl quantile", ylabel = "Modelled $axlbl quantile",
        xlims = lim, ylims = lim, aspect_ratio = :equal, legend = :topleft,
        bottom_margin = 5mm, left_margin = 5mm)
    Plots.plot!(p, collect(lim), collect(lim);
        label = "1:1", color = :black, linestyle = :dash)

    qx = quantile(x, probs)
    qy = quantile(y, probs)
    Plots.scatter!(p, qx, qy; label = "percentiles", color = dotcolor,
        markersize = 6, markerstrokewidth = 1, markerstrokecolor = :black)

    dx = 0.025 * (lim[2] - lim[1])
    dy = 0.025 * (lim[2] - lim[1])
    for i in eachindex(probs)
        lbl = @sprintf("%g%%: %.2f→%.2f", 100 * probs[i], qx[i], qy[i])
        Plots.annotate!(p, qx[i] + dx, qy[i] - dy, Plots.text(lbl, :left, :top, 8))
    end
    return (; probs, qx, qy)
end
