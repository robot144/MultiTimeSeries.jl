
using Test
using Dates
using MultiTimeSeries

const TEST_DATA_DIR = joinpath(@__DIR__, "..", "test_data")
temp_dir = mktempdir()

@testset "MultiTimeSeries" begin

   @testset "Abstract time series tools" begin
      include("test_abstract_series.jl")
   end

   @testset "Time series tools" begin
      include("test_series.jl")
   end

   @testset "NetCDF time series tools" begin
      include("test_series_netcdf.jl")
   end

   @testset "Zarr time series tools" begin
      include("test_series_zarr.jl")
   end

   @testset "JLD2 time series tools" begin
      include("test_series_jld2.jl")
   end

   @testset "NOOS ascii time series tools" begin
      include("test_series_noos.jl")
   end

   @testset "DONAR time series: VLISSGN" begin
      include("test_series_donar.jl")
   end

   @testset "NOOS time series: VLISSGN" begin
      include("test_series_noos_vlissgn.jl")
   end

end
