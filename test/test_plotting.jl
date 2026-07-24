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

# ── scatter plots ─────────────────────────────────────────────────────────────

@testset "scatter(obs, model): single location" begin
    obs   = make_plot_ts_single()
    model = make_plot_ts_single()
    p     = Plots.scatter(obs, model)
    @test p isa Plots.Plot
    save_and_check(p, "scatter_single")
end

@testset "scatter(obs, model): location_index selects one location" begin
    obs   = make_plot_ts_two()
    model = make_plot_ts_two()
    p1    = Plots.scatter(obs, model; location_index=1)
    @test p1 isa Plots.Plot
    save_and_check(p1, "scatter_loc1")

    p2 = Plots.scatter(obs, model; location_index=2)
    @test p2 isa Plots.Plot
    save_and_check(p2, "scatter_loc2")
end

@testset "scatter(obs, model): unit keyword" begin
    obs   = make_plot_ts_single()
    model = make_plot_ts_single()
    p     = Plots.scatter(obs, model; unit="m")
    @test p isa Plots.Plot
    save_and_check(p, "scatter_unit")
end

@testset "scatter(obs, model): NaN values are skipped" begin
    N     = 10
    dt_s  = 3600.0
    t0    = DateTime(2020, 1, 1)
    times = [t0 + Millisecond(round(Int, dt_s * 1000 * (i-1))) for i in 1:N]
    v_obs = Float32.([1, 2, NaN, 4, 5, 6, 7, 8, 9, 10])
    v_mod = Float32.([1, 2, 3,   4, 5, 6, 7, 8, 9, NaN])
    obs   = TimeSeries(reshape(v_obs, 1, N), times, ["S1"], [0.0], [0.0], "level", "test")
    model = TimeSeries(reshape(v_mod, 1, N), times, ["S1"], [0.0], [0.0], "level", "test")
    p     = Plots.scatter(obs, model)   # must not error
    @test p isa Plots.Plot
end

@testset "scatter(obs, model): out-of-range location_index errors" begin
    obs   = make_plot_ts_single()
    model = make_plot_ts_single()
    @test_throws ErrorException Plots.scatter(obs, model; location_index=2)
end

# ── density modes / linear_fit! / qq! ───────────────────────────────────────────

"""Single-location (obs, model≈0.9·obs+noise) pair of length `N` (deterministic)."""
function make_scatter_pair(N)
    t0    = DateTime(2020, 1, 1)
    times = [t0 + Hour(i-1) for i in 1:N]
    o     = Float32.(sin.(2π .* (0:N-1) ./ 37))
    m     = Float32.(0.9 .* o .+ 0.05 .* cos.(2π .* (0:N-1) ./ 13))
    obs   = TimeSeries(reshape(o, 1, N), times, ["S1"], [0.0], [0.0], "level", "obs")
    model = TimeSeries(reshape(m, 1, N), times, ["S1"], [0.0], [0.0], "level", "model")
    return obs, model
end

@testset "scatter density = :points" begin
    obs, model = make_scatter_pair(500)
    p = Plots.scatter(obs, model; density=:points)
    @test p isa Plots.Plot
    save_and_check(p, "scatter_points")
end

@testset "scatter density = :heatmap" begin
    obs, model = make_scatter_pair(500)
    p = Plots.scatter(obs, model; density=:heatmap, nbins=50)
    @test p isa Plots.Plot
    save_and_check(p, "scatter_heatmap")
end

@testset "scatter density = :density_points" begin
    obs, model = make_scatter_pair(500)
    p = Plots.scatter(obs, model; density=:density_points, nbins=50)
    @test p isa Plots.Plot
    save_and_check(p, "scatter_density_points")
end

@testset "scatter density = :auto switches on point count" begin
    small_o, small_m = make_scatter_pair(200)
    large_o, large_m = make_scatter_pair(12_000)
    @test Plots.scatter(small_o, small_m; density=:auto) isa Plots.Plot         # → points
    @test Plots.scatter(large_o, large_m; density=:auto, nbins=80) isa Plots.Plot  # → heatmap
end

@testset "scatter unknown density mode errors" begin
    obs, model = make_scatter_pair(50)
    @test_throws ErrorException Plots.scatter(obs, model; density=:nope)
end

@testset "linear_fit! identity ⇒ slope≈1, offset≈0, r≈1, bias≈0" begin
    obs   = make_plot_ts_single()
    model = make_plot_ts_single()          # identical ⇒ perfect fit
    p  = Plots.scatter(obs, model)
    st = linear_fit!(p, obs, model)
    @test st.slope  ≈ 1.0 atol=1e-6
    @test st.offset ≈ 0.0 atol=1e-6
    @test st.r      ≈ 1.0 atol=1e-6
    @test st.bias   ≈ 0.0 atol=1e-6
    save_and_check(p, "scatter_fit")
end

@testset "linear_fit! recovers a known slope/offset/bias" begin
    N = 200
    t0 = DateTime(2020, 1, 1); times = [t0 + Hour(i-1) for i in 1:N]
    o = Float32.(range(-2, 2; length=N))
    m = Float32.(0.5 .* o .+ 0.3)           # slope 0.5, offset 0.3, no noise
    obs   = TimeSeries(reshape(o, 1, N), times, ["S1"], [0.0], [0.0], "level", "obs")
    model = TimeSeries(reshape(m, 1, N), times, ["S1"], [0.0], [0.0], "level", "model")
    p  = Plots.scatter(obs, model)
    st = linear_fit!(p, obs, model; stats=false)
    @test st.slope  ≈ 0.5 atol=1e-4
    @test st.offset ≈ 0.3 atol=1e-4
    @test st.bias   ≈ sum(m .- o) / N atol=1e-4
end

@testset "linear_fit! on constant observations errors" begin
    N = 10; t0 = DateTime(2020, 1, 1); times = [t0 + Hour(i-1) for i in 1:N]
    o = fill(1.0f0, N); m = Float32.(collect(1:N))
    obs   = TimeSeries(reshape(o, 1, N), times, ["S1"], [0.0], [0.0], "level", "obs")
    model = TimeSeries(reshape(m, 1, N), times, ["S1"], [0.0], [0.0], "level", "model")
    @test_throws ErrorException linear_fit!(Plots.plot(), obs, model)
end

@testset "qq! identity ⇒ qx≈qy, sorted, returns default probs" begin
    obs   = make_plot_ts_single()
    model = make_plot_ts_single()
    q = qq!(Plots.plot(), obs, model)
    @test q.probs == [0.01, 0.10, 0.50, 0.90, 0.99]
    @test q.qx ≈ q.qy atol=1e-6
    @test issorted(q.qx)
end

@testset "qq! custom probs + drawn onto a fresh plot" begin
    obs, model = make_scatter_pair(300)
    p = Plots.plot()
    q = qq!(p, obs, model; probs=[0.25, 0.5, 0.75])
    @test q.probs == [0.25, 0.5, 0.75]
    @test length(q.qx) == 3
    save_and_check(p, "qq_custom")
end
