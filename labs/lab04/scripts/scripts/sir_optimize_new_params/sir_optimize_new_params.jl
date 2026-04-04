using DrWatson
@quickactivate "project"

using BlackBoxOptim, Random, Statistics
using Agents
using JLD2
using DataFrames
using CSV

include(srcdir("sir_model.jl"))

scenario_sets = [
(name = "Базовый сценарий", Is = [0, 0, 1], Ns = [500, 500, 500]),
(name = "Инфекция в первом городе", Is = [1, 0, 0], Ns = [500, 500, 500]),
(name = "Множественное начальное заражение", Is = [5, 0, 0], Ns = [500, 500, 500]),
]

function make_cost_function(scenario)
    function cost_fast(x)
        infected_frac(model) =
            count(a.status == :I for a in allagents(model)) / nagents(model)

        total_population = sum(scenario.Ns)
        dead_count(model) = total_population - nagents(model)

        peak_vals = Float64[]
        dead_vals = Float64[]

        for rep in 1:2
            model = initialize_sir(;
                Ns = scenario.Ns,
                β_und = fill(x[1], 3),
                β_det = fill(x[1] / 10, 3),
                infection_period = 10,
                detection_time = round(Int, x[2]),
                death_rate = x[3],
                reinfection_probability = 0.1,
                Is = scenario.Is,
                seed = 42 + rep,
                n_steps = 50,
            )

            peak_infected = 0.0

            for step in 1:50
                Agents.step!(model, 1)
                frac = infected_frac(model)
                if frac > peak_infected
                    peak_infected = frac
                end
            end

            push!(peak_vals, peak_infected)
            push!(dead_vals, dead_count(model) / total_population)
        end

        mean_peak = mean(peak_vals)
        mean_dead = mean(dead_vals)

        return mean_peak + mean_dead
    end

    return cost_fast
end

results = DataFrame(
    scenario = String[],
    beta_und = Float64[],
    detection_time = Int[],
    death_rate = Float64[],
    fitness = Float64[],
)

for scenario in scenario_sets
    cost_fun = make_cost_function(scenario)

    result = bboptimize(
        cost_fun;
        Method = :random_search,
        SearchRange = [
            (0.1, 1.0),
            (3.0, 14.0),
            (0.01, 0.1),
        ],
        NumDimensions = 3,
        MaxTime = 20,
        TraceMode = :silent,
    )

    best = best_candidate(result)
    fitness = best_fitness(result)

    push!(
        results,
        (
            scenario.name,
            best[1],
            round(Int, best[2]),
            best[3],
            fitness,
        ),
    )

    println("Сценарий: $(scenario.name)")
    println("β_und = $(best[1])")
    println("Время выявления = $(round(Int, best[2])) дней")
    println("Смертность = $(best[3])")
    println("Значение целевой функции = $(fitness)")
    println()
end

results

CSV.write(datadir("optimization_scenarios.csv"), results)

save(
    datadir("optimization_scenarios.jld2"),
    Dict("results" => results),
)
