using DrWatson
@quickactivate "../"

using Agents
using DataFrames
using Plots
using CSV
using Statistics

include("../src/sir_model.jl")

base_params = Dict(
    :Ns => [1000, 1000, 1000],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :n_steps => 100,
)

beta_range = 0.1:0.1:1.0
seeds = [42, 43, 44]

params_list = []

for beta in beta_range
    for seed in seeds
        params = Dict(
            :Ns => base_params[:Ns],
            :β_und => fill(beta, 3),
            :β_det => fill(beta / 10, 3),
            :infection_period => base_params[:infection_period],
            :detection_time => base_params[:detection_time],
            :death_rate => base_params[:death_rate],
            :reinfection_probability => base_params[:reinfection_probability],
            :Is => base_params[:Is],
            :seed => seed,
            :n_steps => base_params[:n_steps],
            :beta => beta,
        )
        push!(params_list, params)
    end
end

function run_experiment(params)
    model = initialize_sir(;
        Ns = params[:Ns],
        β_und = params[:β_und],
        β_det = params[:β_det],
        infection_period = params[:infection_period],
        detection_time = params[:detection_time],
        death_rate = params[:death_rate],
        reinfection_probability = params[:reinfection_probability],
        Is = params[:Is],
        seed = params[:seed],
        n_steps = params[:n_steps],
    )

    infected_values = Int[]

    for step = 1:params[:n_steps]
        Agents.step!(model, 1)
        push!(infected_values, infected_count(model))
    end

    peak_infected = maximum(infected_values)
    final_infected = infected_count(model)
    final_recovered = recovered_count(model)
    total_deaths = sum(params[:Ns]) - total_count(model)

    return (
        peak_infected = peak_infected,
        final_infected = final_infected,
        final_recovered = final_recovered,
        total_deaths = total_deaths,
    )
end

results = DataFrame(
    beta = Float64[],
    seed = Int[],
    peak_infected = Int[],
    final_infected = Int[],
    final_recovered = Int[],
    total_deaths = Int[],
)

for params in params_list
    res = run_experiment(params)

    push!(
        results,
        (
            params[:beta],
            params[:seed],
            res.peak_infected,
            res.final_infected,
            res.final_recovered,
            res.total_deaths,
        ),
    )
end

first(results, 10)

CSV.write(datadir("sir_params_results.csv"), results)

grouped_results = combine(
    groupby(results, :beta),
    :peak_infected => mean => :mean_peak_infected,
    :final_infected => mean => :mean_final_infected,
    :final_recovered => mean => :mean_final_recovered,
    :total_deaths => mean => :mean_total_deaths,
)

grouped_results

plot(
    grouped_results.beta,
    grouped_results.mean_peak_infected,
    label = "Средний пик инфицированных",
    xlabel = "beta",
    ylabel = "Количество",
    lw = 2,
)

plot!(
    grouped_results.beta,
    grouped_results.mean_final_infected,
    label = "Среднее конечное число инфицированных",
    lw = 2,
)

plot!(
    grouped_results.beta,
    grouped_results.mean_final_recovered,
    label = "Среднее конечное число выздоровевших",
    lw = 2,
)

plot!(
    grouped_results.beta,
    grouped_results.mean_total_deaths,
    label = "Среднее число умерших",
    lw = 2,
)

savefig(plotsdir("sir_params_scan.png"))
