using DrWatson
@quickactivate "project"

include(srcdir("MMCModel.jl"))
using .MMCModel

using DataFrames
using CSV
using Plots

# Параметры модели M/M/c
params = MMCParameters(
    num_customers = 200,
    num_servers = 2,
    lambda = 0.9,
    mu = 0.5,
    seed = 123,
)

# Запуск симуляции
result = run_mmc_simulation(params)

# Печать краткой сводки
print_mmc_summary(result)

# Аналитические характеристики M/M/c
analytics = mmc_analytics(params)

println()
println("Analytical M/M/c characteristics:")
println(analytics)

# Сохранение таблиц
CSV.write(datadir("mmc_events.csv"), result.events)
CSV.write(datadir("mmc_customers.csv"), result.customers)
CSV.write(datadir("mmc_metrics.csv"), result.metrics)
CSV.write(datadir("mmc_analytics.csv"), analytics)

# Сравнительная таблица имитационных и аналитических значений
summary = DataFrame(
    metric = [
        "average waiting time",
        "average system time",
        "utilization",
    ],
    simulation = [
        result.metrics.avg_waiting_time[1],
        result.metrics.avg_system_time[1],
        result.metrics.utilization[1],
    ],
    analytical = [
        analytics.Wq[1],
        analytics.W[1],
        analytics.rho[1],
    ],
)

CSV.write(datadir("mmc_summary.csv"), summary)

# График длины очереди во времени
p_queue = plot(
    result.events.time,
    result.events.queue_length,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Queue length",
    title = "M/M/c queue length",
    label = "Queue",
    linewidth = 2,
)

savefig(p_queue, plotsdir("mmc_queue_length.png"))

# График числа занятых каналов обслуживания
p_busy = plot(
    result.events.time,
    result.events.busy_servers,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Busy servers",
    title = "M/M/c busy servers",
    label = "Busy servers",
    linewidth = 2,
)

savefig(p_busy, plotsdir("mmc_busy_servers.png"))

# График времени ожидания заявок
p_wait = plot(
    result.customers.customer_id,
    result.customers.waiting_time,
    xlabel = "Customer ID",
    ylabel = "Waiting time",
    title = "M/M/c waiting time by customer",
    label = "Waiting time",
    marker = :circle,
    linewidth = 2,
)

savefig(p_wait, plotsdir("mmc_waiting_time.png"))

# График времени пребывания заявок в системе
p_system = plot(
    result.customers.customer_id,
    result.customers.system_time,
    xlabel = "Customer ID",
    ylabel = "System time",
    title = "M/M/c system time by customer",
    label = "System time",
    marker = :circle,
    linewidth = 2,
)

savefig(p_system, plotsdir("mmc_system_time.png"))

# Сравнение имитационных и аналитических значений
p_compare = bar(
    summary.metric,
    [summary.simulation summary.analytical],
    label = ["Simulation" "Analytical"],
    xlabel = "Metric",
    ylabel = "Value",
    title = "M/M/c simulation and analytical comparison",
    xrotation = 20,
)

savefig(p_compare, plotsdir("mmc_simulation_vs_analytics.png"))

println()
println("M/M/c simulation completed.")
println("Saved data:")
println("  data/mmc_events.csv")
println("  data/mmc_customers.csv")
println("  data/mmc_metrics.csv")
println("  data/mmc_analytics.csv")
println("  data/mmc_summary.csv")
println("Saved plots:")
println("  plots/mmc_queue_length.png")
println("  plots/mmc_busy_servers.png")
println("  plots/mmc_waiting_time.png")
println("  plots/mmc_system_time.png")
println("  plots/mmc_simulation_vs_analytics.png")
