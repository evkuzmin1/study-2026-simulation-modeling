using DrWatson
@quickactivate "project"

using BlackBoxOptim, Random, Statistics
using Agents
using JLD2

include(srcdir("sir_model.jl"))

function cost_fast(x)
infected_frac(model) =
count(a.status == :I for a in allagents(model)) / nagents(model)

dead_count(model) = 1500 - nagents(model)

peak_vals = Float64[]
dead_vals = Float64[]

for rep in 1:2
model = initialize_sir(;
Ns = [500, 500, 500],
β_und = fill(x[1], 3),
β_det = fill(x[1] / 10, 3),
infection_period = 10,
detection_time = round(Int, x[2]),
death_rate = x[3],
reinfection_probability = 0.1,
Is = [0, 0, 1],
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
push!(dead_vals, dead_count(model) / 1500)
end

mean_peak = mean(peak_vals)
mean_dead = mean(dead_vals)

return mean_peak + mean_dead
end

result = bboptimize(
cost_fast;
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

println("Оптимальные параметры:")
println("β_und = $(best[1])")
println("Время выявления = $(round(Int, best[2])) дней")
println("Смертность = $(best[3])")

println("Значение целевой функции: $(fitness)")

save(
datadir("optimization_fast_result.jld2"),
Dict(
"best" => best,
"fitness" => fitness,
),
)
