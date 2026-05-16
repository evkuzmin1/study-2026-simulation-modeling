using DrWatson
@quickactivate "project"

include(srcdir("RossModel.jl"))
using .RossModel

using DataFrames
using CSV
using Plots

# Параметры базового запуска модели Росса.
params = RossParameters(
    num_operating = 5,
    num_spares = 3,
    num_repairers = 1,
    failure_rate = 0.1,
    repair_rate = 0.5,
    seed = 123,
    max_time = 1000.0,
)

# Запуск одной симуляции модели Росса.
result = run_ross_simulation(params)

# Краткая сводка по базовому запуску.
print_ross_summary(result)

# Серия независимых повторов для оценки среднего времени до отказа.
replications = run_ross_replications(params; n_replications = 100)

println()
println("Ross model replications summary:")
println(replications.summary)

# Сохранение результатов моделирования.
CSV.write(datadir("ross_history.csv"), result.history)
CSV.write(datadir("ross_metrics.csv"), result.metrics)
CSV.write(datadir("ross_replications.csv"), replications.replications)
CSV.write(datadir("ross_replications_summary.csv"), replications.summary)

# Сравнение среднего времени до отказа по симуляции и аналитической оценки.
comparison = DataFrame(
    metric = ["Simulation mean", "Analytical MTTF"],
    value = [
        replications.summary.mean_time_to_failure[1],
        replications.summary.analytic_mttf[1],
    ],
)

CSV.write(datadir("ross_mttf_comparison.csv"), comparison)

# График числа доступных резервных машин во времени.
p_spares = plot(
    result.history.time,
    result.history.spares_available,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Available spares",
    title = "Ross model: available spare machines",
    label = "Spares",
    linewidth = 2,
)

savefig(p_spares, plotsdir("ross_spares_available.png"))

# График длины очереди на ремонт.
p_queue = plot(
    result.history.time,
    result.history.repair_queue,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Repair queue length",
    title = "Ross model: repair queue",
    label = "Repair queue",
    linewidth = 2,
)

savefig(p_queue, plotsdir("ross_repair_queue.png"))

# График числа занятых ремонтников.
p_busy = plot(
    result.history.time,
    result.history.repairers_busy,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Busy repairers",
    title = "Ross model: busy repairers",
    label = "Busy repairers",
    linewidth = 2,
)

savefig(p_busy, plotsdir("ross_busy_repairers.png"))

# График времени до отказа по независимым повторам.
p_ttf = plot(
    replications.replications.replication,
    replications.replications.time_to_failure,
    xlabel = "Replication",
    ylabel = "Time to failure",
    title = "Ross model: time to failure by replication",
    label = "Time to failure",
    marker = :circle,
    linewidth = 2,
)

savefig(p_ttf, plotsdir("ross_time_to_failure.png"))

# Сравнение среднего времени до отказа с аналитическим значением.
p_compare = bar(
    comparison.metric,
    comparison.value,
    xlabel = "Method",
    ylabel = "Mean time to failure",
    title = "Ross model: simulation and analytical MTTF",
    label = "MTTF",
    xrotation = 15,
)

savefig(p_compare, plotsdir("ross_mttf_comparison.png"))

println()
println("Ross model simulation completed.")
println("Saved data:")
println("  data/ross_history.csv")
println("  data/ross_metrics.csv")
println("  data/ross_replications.csv")
println("  data/ross_replications_summary.csv")
println("  data/ross_mttf_comparison.csv")
println("Saved plots:")
println("  plots/ross_spares_available.png")
println("  plots/ross_repair_queue.png")
println("  plots/ross_busy_repairers.png")
println("  plots/ross_time_to_failure.png")
println("  plots/ross_mttf_comparison.png")
