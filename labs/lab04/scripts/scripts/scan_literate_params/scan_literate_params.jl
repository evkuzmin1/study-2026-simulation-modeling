using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Random
using Statistics

include(srcdir("sir_model.jl"))

function run_experiment(p)
beta = p[:beta]
β_und = fill(beta, 3)
β_det = fill(beta / 10, 3)

model = initialize_sir(;
Ns = p[:Ns],
β_und = β_und,
β_det = β_det,
infection_period = p[:infection_period],
detection_time = p[:detection_time],
death_rate = p[:death_rate],
reinfection_probability = p[:reinfection_probability],
Is = p[:Is],
seed = p[:seed],
n_steps = p[:n_steps],
)

infected_fraction(model) =
count(a.status == :I for a in allagents(model)) / nagents(model)

peak_infected = 0.0

for step = 1:p[:n_steps]
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

frac = infected_fraction(model)
if frac > peak_infected
peak_infected = frac
end
end

final_infected = infected_fraction(model)
final_recovered = count(a.status == :R for a in allagents(model)) / nagents(model)
total_deaths = sum(p[:Ns]) - nagents(model)

return (
peak = peak_infected,
final_inf = final_infected,
final_rec = final_recovered,
deaths = total_deaths,
)
end

scenario_sets = [
(name = "Быстрое выявление", detection_time = 5),
(name = "Базовое выявление", detection_time = 7),
(name = "Позднее выявление", detection_time = 10),
]

beta_range = 0.1:0.1:1.0
seeds = [42, 43, 44]

params_list = []

for scenario in scenario_sets
for b in beta_range
for s in seeds
push!(
params_list,
Dict(
:scenario => scenario.name,
:beta => b,
:Ns => [1000, 1000, 1000],
:infection_period => 14,
:detection_time => scenario.detection_time,
:death_rate => 0.02,
:reinfection_probability => 0.1,
:Is => [0, 0, 1],
:seed => s,
:n_steps => 100,
),
)
end
end
end

results = []

for params in params_list
data = run_experiment(params)
push!(results, merge(params, Dict(pairs(data))))
println("Сценарий = $(params[:scenario]), beta = $(params[:beta]), seed = $(params[:seed])")
end

df = DataFrame(results)
CSV.write(datadir("beta_scan_scenarios_all.csv"), df)

grouped = combine(
groupby(df, [:scenario, :beta]),
:peak => mean => :mean_peak,
:final_inf => mean => :mean_final_inf,
:final_rec => mean => :mean_final_rec,
:deaths => mean => :mean_deaths,
)

CSV.write(datadir("beta_scan_scenarios_grouped.csv"), grouped)

plot(
xlabel = "Коэффициент заразности β",
ylabel = "Средняя доля инфицированных",
title = "Сравнение пика эпидемии для разных сценариев",
linewidth = 2,
)

for scenario in scenario_sets
subset_df = grouped[grouped.scenario .== scenario.name, :]
plot!(
subset_df.beta,
subset_df.mean_peak,
label = scenario.name,
marker = :circle,
)
end

savefig(plotsdir("beta_scan_scenarios_peak.png"))

plot(
xlabel = "Коэффициент заразности β",
ylabel = "Средняя доля умерших",
title = "Сравнение смертности для разных сценариев",
linewidth = 2,
)

for scenario in scenario_sets
subset_df = grouped[grouped.scenario .== scenario.name, :]
plot!(
subset_df.beta,
subset_df.mean_deaths ./ 3000,
label = scenario.name,
marker = :diamond,
)
end

savefig(plotsdir("beta_scan_scenarios_deaths.png"))

println("Результаты сохранены в data/beta_scan_scenarios_all.csv")
println("Усреднённые результаты сохранены в data/beta_scan_scenarios_grouped.csv")
println("Графики сохранены в plots/beta_scan_scenarios_peak.png и plots/beta_scan_scenarios_deaths.png")
