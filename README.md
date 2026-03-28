# MultiTimeSeries

A Julia package for multi-location time series of physical quantities (water levels, wave heights, wind speed, etc.).

## Features

- In-memory `TimeSeries` struct with locations × time layout
- Read/write support for NOOS, DONAR, NetCDF, Zarr, and JLD2 formats
- Selection by location (index or name) and by time span
- Merging by time or by location

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

## Supported formats

| Format | Read | Write |
|--------|------|-------|
| NOOS (ascii) | `read_single_noos_file`, `NoosTimeSeriesCollection` | `write_single_noos_file` |
| DONAR (ascii) | `read_donar_timeseries` | — |
| NetCDF | `NetCDFTimeSeries` | `write_to_netcdf` |
| Zarr | `ZarrTimeSeries` | — |
| JLD2 | `JLD2TimeSeries` | `write_to_jld2` |
