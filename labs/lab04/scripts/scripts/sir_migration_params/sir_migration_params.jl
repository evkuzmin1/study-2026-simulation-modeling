using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Random
using Statistics

include(srcdir("sir_model.jl"))

function create_migration_matrix(C, intensity)
M = ones(C, C) .* intensity / (C - 1)
for i in 1:C
M[i, i] = 1 - intensity
end
return M
end

function peak_time(p)
migration_rates = create_migration_matrix(p[:C], p[:migration_intensity])

model = initialize_sir(;
Ns = p[:Ns],
β_und = p[:β_und],
β_det = p[:β_det],
infection_period = p[:infection_period],
detection_time = p[:detection_time],
death_rate = p[:death_rate],
reinfection_probability = p[:reinfection_probability],
Is = p[:Is],
seed = p[:seed],
migration_rates = migration_rates,
)

infected_frac(model) =
count(a.status == :I for a in allagents(model)) / nagents(model)

peak = 0.0
peak_step = 0

for step in 1:p[:n_steps]
agent_ids = collect(allids(model))
for id in agent_ids
agent = try
model[id]
catch
nothing
end

if agent !== nothing
sir_agent_step!(agent, model)
end
end

frac = infected_frac(model)
if frac > peak
peak = frac
peak_step = step
end
end

return (peak_time = peak_step, peak_value = peak)
end

scenario_sets = [
(name = "Низкая заразность", β_und = [0.3, 0.3, 0.3], β_det = [0.03, 0.03, 0.03]),
(name = "Базовая заразность", β_und = [0.5, 0.5, 0.5], β_det = [0.05, 0.05, 0.05]),
(name = "Высокая заразность", β_und = [0.7, 0.7, 0.7], β_det = [0.07, 0.07, 0.07]),
]

migration_intensities = 0.0:0.1:0.5
seeds = [42, 43, 44]

params_list = []

for scenario in scenario_sets
for mig in migration_intensities
for s in seeds
push!(
params_list,
Dict(
:scenario => scenario.name,
:migration_intensity => mig,
:C => 3,
:Ns => [1000, 1000, 1000],
:β_und => scenario.β_und,
:β_det => scenario.β_det,
:infection_period => 14,
:detection_time => 7,
:death_rate => 0.02,
:reinfection_probability => 0.1,
:Is => [1, 0, 0],
:seed => s,
:n_steps => 150,
),
)
end
end
end

results = []

for params in params_list
data = peak_time(params)
push!(results, merge(params, Dict(pairs(data))))
println("Сценарий = $(params[:scenario]), migration = $(params[:migration_intensity]), seed = $(params[:seed])")
end

df = DataFrame(results)
CSV.write(datadir("migration_scenarios_all.csv"), df)

grouped = combine(
groupby(df, [:scenario, :migration_intensity]),
:peak_time => mean => :mean_peak_time,
:peak_value => mean => :mean_peak_value,
)

CSV.write(datadir("migration_scenarios_grouped.csv"), grouped)

plot(
xlabel = "Интенсивность миграции",
ylabel = "Среднее время до пика (дни)",
title = "Влияние миграции на время достижения пика",
linewidth = 2,
)

for scenario in scenario_sets
subset_df = grouped[grouped.scenario .== scenario.name, :]
plot!(
subset_df.migration_intensity,
subset_df.mean_peak_time,
label = scenario.name,
marker = :circle,
)
end

savefig(plotsdir("migration_scenarios_peak_time.png"))

plot(
xlabel = "Интенсивность миграции",
ylabel = "Средняя численность в пике",
title = "Влияние миграции на пиковую заболеваемость",
linewidth = 2,
)

for scenario in scenario_sets
subset_df = grouped[grouped.scenario .== scenario.name, :]
plot!(
subset_df.migration_intensity,
subset_df.mean_peak_value .* 3000,
label = scenario.name,
marker = :square,
)
end

savefig(plotsdir("migration_scenarios_peak_value.png"))

println("Результаты сохранены в data/migration_scenarios_all.csv")
println("Усреднённые результаты сохранены в data/migration_scenarios_grouped.csv")
println("Графики сохранены в plots/migration_scenarios_peak_time.png и plots/migration_scenarios_peak_value.png")
