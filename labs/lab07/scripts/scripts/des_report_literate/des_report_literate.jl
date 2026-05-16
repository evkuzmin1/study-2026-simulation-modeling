using DrWatson
@quickactivate "project"

using DataFrames
using CSV
using Plots

mmc_metrics = CSV.read(datadir("mmc_metrics.csv"), DataFrame)
mmc_analytics = CSV.read(datadir("mmc_analytics.csv"), DataFrame)
mmc_summary = CSV.read(datadir("mmc_summary.csv"), DataFrame)
mmc_params_compare = CSV.read(datadir("mmc_params_compare.csv"), DataFrame)

ross_metrics = CSV.read(datadir("ross_metrics.csv"), DataFrame)
ross_replications_summary = CSV.read(datadir("ross_replications_summary.csv"), DataFrame)
ross_mttf_comparison = CSV.read(datadir("ross_mttf_comparison.csv"), DataFrame)
ross_params_summary = CSV.read(datadir("ross_params_summary.csv"), DataFrame)
ross_params_mttf_compare = CSV.read(datadir("ross_params_mttf_compare.csv"), DataFrame)

mmc_final_summary = DataFrame(
    model = ["M/M/c"],
    num_customers = [mmc_metrics.num_customers[1]],
    num_servers = [mmc_metrics.num_servers[1]],
    lambda = [mmc_metrics.lambda[1]],
    mu = [mmc_metrics.mu[1]],
    rho_simulation = [mmc_metrics.utilization[1]],
    rho_analytical = [mmc_analytics.rho[1]],
    avg_waiting_time_simulation = [mmc_metrics.avg_waiting_time[1]],
    avg_waiting_time_analytical = [mmc_analytics.Wq[1]],
    avg_system_time_simulation = [mmc_metrics.avg_system_time[1]],
    avg_system_time_analytical = [mmc_analytics.W[1]],
    max_queue_length = [mmc_metrics.max_queue_length[1]],
)

CSV.write(datadir("des_mmc_final_summary.csv"), mmc_final_summary)

ross_final_summary = DataFrame(
    model = ["Ross model"],
    num_operating = [ross_metrics.num_operating[1]],
    num_spares = [ross_metrics.num_spares[1]],
    num_repairers = [ross_metrics.num_repairers[1]],
    failure_rate = [ross_metrics.failure_rate[1]],
    repair_rate = [ross_metrics.repair_rate[1]],
    time_to_failure_single_run = [ross_metrics.time_to_failure[1]],
    mean_time_to_failure_simulation = [
        ross_replications_summary.mean_time_to_failure[1],
    ],
    mean_time_to_failure_analytical = [
        ross_replications_summary.analytic_mttf[1],
    ],
    avg_repair_queue = [ross_metrics.avg_repair_queue[1]],
    repairer_utilization = [ross_metrics.repairer_utilization[1]],
)

CSV.write(datadir("des_ross_final_summary.csv"), ross_final_summary)

des_overview = DataFrame(
    model = [
        "M/M/c",
        "Ross model",
    ],
    object = [
        "Queueing system with several service channels",
        "Reliability system with spare machines and repairers",
    ],
    main_variable = [
        "Number of servers",
        "Number of repairers",
    ],
    main_metric = [
        "Waiting time and queue length",
        "Mean time to failure and repair queue",
    ],
    conclusion = [
        "Increasing the number of servers reduces waiting time and queue length.",
        "Increasing the number of repairers increases mean time to failure and reduces repair queue.",
    ],
)

CSV.write(datadir("des_overview.csv"), des_overview)

x_mmc = collect(1:nrow(mmc_summary))

p_mmc_compare = bar(
    x_mmc .- 0.15,
    mmc_summary.simulation,
    bar_width = 0.3,
    label = "Simulation",
    xlabel = "Metric",
    ylabel = "Value",
    title = "M/M/c: simulation and analytical comparison",
    xticks = (x_mmc, mmc_summary.metric),
    xrotation = 20,
)

bar!(
    p_mmc_compare,
    x_mmc .+ 0.15,
    mmc_summary.analytical,
    bar_width = 0.3,
    label = "Analytical",
)

savefig(p_mmc_compare, plotsdir("des_mmc_simulation_vs_analytics.png"))

x_servers = collect(mmc_params_compare.num_servers)

p_mmc_time = plot(
    x_servers,
    mmc_params_compare.avg_waiting_time_mean,
    marker = :circle,
    xlabel = "Number of servers",
    ylabel = "Time",
    title = "M/M/c: effect of servers on time metrics",
    label = "Average waiting time",
    linewidth = 2,
)

plot!(
    p_mmc_time,
    x_servers,
    mmc_params_compare.avg_system_time_mean,
    marker = :circle,
    label = "Average system time",
    linewidth = 2,
)

savefig(p_mmc_time, plotsdir("des_mmc_time_by_servers.png"))

p_mmc_queue = plot(
    x_servers,
    mmc_params_compare.max_queue_length_mean,
    marker = :circle,
    xlabel = "Number of servers",
    ylabel = "Average max queue length",
    title = "M/M/c: effect of servers on queue length",
    label = "Max queue length",
    linewidth = 2,
)

savefig(p_mmc_queue, plotsdir("des_mmc_queue_by_servers.png"))

x_ross = collect(1:nrow(ross_mttf_comparison))

p_ross_compare = bar(
    x_ross,
    ross_mttf_comparison.value,
    xlabel = "Method",
    ylabel = "Mean time to failure",
    title = "Ross model: simulation and analytical MTTF",
    label = "MTTF",
    xticks = (x_ross, ross_mttf_comparison.metric),
    xrotation = 15,
)

savefig(p_ross_compare, plotsdir("des_ross_mttf_comparison.png"))

x_repairers_compare = collect(ross_params_mttf_compare.num_repairers)

p_ross_mttf = plot(
    x_repairers_compare,
    ross_params_mttf_compare.simulation_mttf,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Mean time to failure",
    title = "Ross model: effect of repairers on MTTF",
    label = "Simulation mean",
    linewidth = 2,
)

plot!(
    p_ross_mttf,
    x_repairers_compare,
    ross_params_mttf_compare.analytical_mttf,
    marker = :circle,
    label = "Analytical MTTF",
    linewidth = 2,
)

savefig(p_ross_mttf, plotsdir("des_ross_mttf_by_repairers.png"))

x_repairers = collect(ross_params_summary.num_repairers)

p_ross_queue = plot(
    x_repairers,
    ross_params_summary.mean_repair_queue,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Value",
    title = "Ross model: repair queue and utilization",
    label = "Mean repair queue",
    linewidth = 2,
)

plot!(
    p_ross_queue,
    x_repairers,
    ross_params_summary.mean_repairer_utilization,
    marker = :circle,
    label = "Repairer utilization",
    linewidth = 2,
)

savefig(p_ross_queue, plotsdir("des_ross_queue_utilization.png"))

println("Discrete-event simulation report completed.")

println()
println("Saved data:")
println("  data/des_mmc_final_summary.csv")
println("  data/des_ross_final_summary.csv")
println("  data/des_overview.csv")

println()
println("Saved plots:")
println("  plots/des_mmc_simulation_vs_analytics.png")
println("  plots/des_mmc_time_by_servers.png")
println("  plots/des_mmc_queue_by_servers.png")
println("  plots/des_ross_mttf_comparison.png")
println("  plots/des_ross_mttf_by_repairers.png")
println("  plots/des_ross_queue_utilization.png")
