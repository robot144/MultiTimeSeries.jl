# MultiTimeSeries

A Julia package for multi-location time series of physical quantities (water levels, wave heights, wind speed, etc.).

> **Note:** This package was written for internal research use and provides a minimal interface tailored to multi-location hydrodynamic data. For general-purpose time series work in Julia, the standard choice is [TimeSeries.jl](https://github.com/JuliaStats/TimeSeries.jl).

## Features

- In-memory `TimeSeries` struct with locations × time layout
- Read/write support for NOOS, DONAR, NetCDF, Zarr, and JLD2 formats
- Selection by location (index or name) and by time span
- Merging by time or by location
- Per-station validation statistics (bias, RMSE, MAE, …)
- Time-series plotting via [Plots.jl](https://docs.juliaplots.org/)

## Installation

```julia
using Pkg
Pkg.add(path="path/to/MultiTimeSeries")
```

## Quick start

```julia
using MultiTimeSeries, Dates

# Create a time series
times  = collect(DateTime(2020,1,1):Hour(1):DateTime(2020,1,2))
values = rand(Float32, 2, length(times))   # [locations × times]
ts = TimeSeries(values, times,
                ["Station A", "Station B"],
                [4.0, 5.0], [52.0, 53.0],
                "water level", "model")

# Getters
get_names(ts)       # ["Station A", "Station B"]
get_times(ts)       # Vector{DateTime}
get_values(ts)      # Matrix{Float32}

# Select a location or a time window
ts_a    = select_location_by_name(ts, "Station A")
ts_sub  = select_timespan(ts, DateTime(2020,1,1,6), DateTime(2020,1,1,18))

# Read from file formats
ts_nc   = NetCDFTimeSeries("data.nc", "waterlevel")
ts_zarr = ZarrTimeSeries("data.zarr", "waterlevel")
ts_jld2 = JLD2TimeSeries("data.jld2")
ts_noos = read_single_noos_file("station.noos")
ts_don  = read_donar_timeseries("station.txt")
```

## The `TimeSeries` struct

Values are stored as `Matrix{Float32}` with rows = locations and columns = time steps.

| Field | Type | Description |
|-------|------|-------------|
| `values` | `Matrix{Float32}` | data `[locations × times]` |
| `times` | `Vector{DateTime}` | time steps |
| `names` | `Vector{String}` | station names |
| `longitudes` | `Vector{Float64}` | station longitudes |
| `latitudes` | `Vector{Float64}` | station latitudes |
| `quantity` | `String` | physical quantity |
| `source` | `String` | data provenance |

## Statistics

`compute_statistics` compares a model `TimeSeries` against observations and returns a `DataFrame` with one row per station. Both series must share the same time axis and location names; use `select_timespan` / `merge_by_times` to align them first.

```julia
using MultiTimeSeries, DataFrames

stats = compute_statistics(obs, model)
# => DataFrame with columns:
#    location_id, location_name, n_values,
#    signal_rmse, bias, rmse, mae, max_error, min_error
```

Time steps where either series contains `NaN` are excluded automatically.

## Plotting

`Plots.plot` is extended for `AbstractTimeSeries` when [Plots.jl](https://docs.juliaplots.org/) is loaded. It plots one location at a time, selected by `location_index`.

```julia
using MultiTimeSeries, Plots

p = Plots.plot(ts)                          # first location
p = Plots.plot(ts; location_index=2)        # second location
p = Plots.plot(ts; yunit="m", size=(900,300))
```

## Supported formats

| Format | Read | Write |
|--------|------|-------|
| NOOS (ascii) | `read_single_noos_file`, `NoosTimeSeriesCollection` | `write_single_noos_file` |
| DONAR (ascii) | `read_donar_timeseries` | — |
| NetCDF | `NetCDFTimeSeries` | `write_to_netcdf` |
| Zarr | `ZarrTimeSeries` | — |
| JLD2 | `JLD2TimeSeries` | `write_to_jld2` |
