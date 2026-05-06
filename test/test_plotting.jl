# test_plotting.jl
# Tests for src/plotting.jl — Plots.plot(AbstractTimeSeries)
#
# All fixtures are synthetic: no tidal or external data dependency.

import Plots
Plots.gr()   # headless GR backend — no display required

# ── output directory: wipe and recreate on every run ──────────────────────────

const PLOT_DIR = joinpath(@__DIR__, "temp")
rm(PLOT_DIR; recursive=true, force=true)
mkpath(PLOT_DIR)

# ── fixtures ──────────────────────────────────────────────────────────────────

"""Single-location TimeSeries with a simple sine signal."""
function make_plot_ts_single()
    N     = 48
    dt_s  = 3600.0
    t0    = DateTime(2020, 1, 1)
    times = [t0 + Millisecond(round(Int, dt_s * 1000 * (i-1))) for i in 1:N]
    vals  = Float32.(sin.(2π .* (0:N-1) ./ N))
    return TimeSeries(reshape(vals, 1, N), times, ["S1"],
                      [4.0], [51.0], "water level", "synthetic")
end

"""Two-location TimeSeries."""
function make_plot_ts_two()
    N     = 48
    dt_s  = 3600.0
    t0    = DateTime(2020, 1, 1)
    times = [t0 + Millisecond(round(Int, dt_s * 1000 * (i-1))) for i in 1:N]
    v1    = Float32.(sin.(2π .* (0:N-1) ./ N))
    v2    = Float32.(cos.(2π .* (0:N-1) ./ N))
    vals  = vcat(reshape(v1, 1, N), reshape(v2, 1, N))
    return TimeSeries(vals, times, ["S1", "S2"],
                      [4.0, 5.0], [51.0, 52.0], "water level", "synthetic")
end

# ── helper ─────────────────────────────────────────────────────────────────────

"""Save `p` to test/temp/<name>.png and assert the file is non-empty."""
function save_and_check(p::Plots.Plot, name::String)
    path = joinpath(PLOT_DIR, name * ".png")
    Plots.savefig(p, path)
    @test isfile(path)
    @test filesize(path) > 1_000
end

# ── tests ─────────────────────────────────────────────────────────────────────

@testset "plot(TimeSeries): single location" begin
    ts = make_plot_ts_single()
    p  = Plots.plot(ts)
    @test p isa Plots.Plot
    save_and_check(p, "ts_single")
end

@testset "plot(TimeSeries): location_index selects one location" begin
    ts = make_plot_ts_two()
    p1 = Plots.plot(ts; location_index=1)
    @test p1 isa Plots.Plot
    save_and_check(p1, "ts_loc1")

    p2 = Plots.plot(ts; location_index=2)
    @test p2 isa Plots.Plot
    save_and_check(p2, "ts_loc2")
end

@testset "plot(TimeSeries): out-of-range location_index errors" begin
    ts = make_plot_ts_single()   # 1 location
    @test_throws ErrorException Plots.plot(ts; location_index=2)
end

@testset "plot(TimeSeries): yunit keyword" begin
    ts = make_plot_ts_single()
    p  = Plots.plot(ts; yunit="m")
    @test p isa Plots.Plot
    save_and_check(p, "ts_yunit")
end

@testset "plot(TimeSeries): size and dpi kwargs forwarded" begin
    ts = make_plot_ts_single()
    p  = Plots.plot(ts; size=(800, 400), dpi=150)
    save_and_check(p, "ts_custom_size")
end
