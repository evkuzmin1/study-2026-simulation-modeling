using DrWatson
@quickactivate "project"

include(srcdir("RossModel.jl"))
using .RossModel

using DataFrames
using CSV
using Plots
using Statistics

num_operating = 5
num_spares = 3

failure_rate = 0.1
repair_rate = 0.5

repairer_counts = [1, 2, 3, 4]

n_replications = 100
base_seed = 500
max_time = 1000.0

all_replications = []
summary_rows = []
analytics_rows = []
sample_history_rows = []

for repairers in repairer_counts
    params = RossParameters(
        num_operating = num_operating,
        num_spares = num_spares,
        num_repairers = repairers,
        failure_rate = failure_rate,
        repair_rate = repair_rate,
        seed = base_seed + 100 * repairers,
        max_time = max_time,
    )

    sample_result = run_ross_simulation(params)

    for row in eachrow(sample_result.history)
        push!(
            sample_history_rows,
            (
                num_repairers = repairers,
                time = row.time,
                event = row.event,
                operating_machines = row.operating_machines,
                spares_available = row.spares_available,
                repair_queue = row.repair_queue,
                repairers_busy = row.repairers_busy,
                broken_total = row.broken_total,
                failed = row.failed,
            ),
        )
    end

    replications = run_ross_replications(
        params;
        n_replications = n_replications,
    )

    for row in eachrow(replications.replications)
        push!(
            all_replications,
            (
                num_repairers = repairers,
                replication = row.replication,
                seed = row.seed,
                time_to_failure = row.time_to_failure,
                failed = row.failed,
                avg_repair_queue = row.avg_repair_queue,
                repairer_utilization = row.repairer_utilization,
            ),
        )
    end

    summary = replications.summary
    analytic_mttf = ross_analytic_mttf(params)

    push!(
        summary_rows,
        (
            num_repairers = repairers,
            num_operating = num_operating,
            num_spares = num_spares,
            failure_rate = failure_rate,
            repair_rate = repair_rate,
            n_replications = n_replications,
            mean_time_to_failure = summary.mean_time_to_failure[1],
            std_time_to_failure = summary.std_time_to_failure[1],
            min_time_to_failure = summary.min_time_to_failure[1],
            max_time_to_failure = summary.max_time_to_failure[1],
            mean_repair_queue = summary.mean_repair_queue[1],
            mean_repairer_utilization = summary.mean_repairer_utilization[1],
            analytic_mttf = analytic_mttf,
        ),
    )

    push!(
        analytics_rows,
        (
            num_repairers = repairers,
            analytic_mttf = analytic_mttf,
        ),
    )
end

df_replications = DataFrame(all_replications)
df_summary = DataFrame(summary_rows)
df_analytics = DataFrame(analytics_rows)
df_sample_history = DataFrame(sample_history_rows)

df_compare = DataFrame(
    num_repairers = df_summary.num_repairers,
    simulation_mttf = df_summary.mean_time_to_failure,
    analytical_mttf = df_summary.analytic_mttf,
    absolute_difference = abs.(
        df_summary.mean_time_to_failure .- df_summary.analytic_mttf,
    ),
)

CSV.write(datadir("ross_params_replications.csv"), df_replications)
CSV.write(datadir("ross_params_summary.csv"), df_summary)
CSV.write(datadir("ross_params_analytics.csv"), df_analytics)
CSV.write(datadir("ross_params_sample_history.csv"), df_sample_history)
CSV.write(datadir("ross_params_mttf_compare.csv"), df_compare)

println("Ross model parameter experiment summary:")
println(df_summary)

println()
println("Simulation and analytical MTTF comparison:")
println(df_compare)

p_mttf = plot(
    df_summary.num_repairers,
    [df_summary.mean_time_to_failure df_summary.analytic_mttf],
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Mean time to failure",
    title = "Ross model: mean time to failure",
    label = ["Simulation mean" "Analytical MTTF"],
    linewidth = 2,
)

savefig(p_mttf, plotsdir("ross_params_mttf.png"))

p_queue = plot(
    df_summary.num_repairers,
    df_summary.mean_repair_queue,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Mean repair queue",
    title = "Ross model: mean repair queue",
    label = "Repair queue",
    linewidth = 2,
)

savefig(p_queue, plotsdir("ross_params_queue.png"))

p_util = plot(
    df_summary.num_repairers,
    df_summary.mean_repairer_utilization,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Repairer utilization",
    title = "Ross model: repairer utilization",
    label = "Utilization",
    linewidth = 2,
)

savefig(p_util, plotsdir("ross_params_utilization.png"))

p_box = boxplot(
    string.(df_replications.num_repairers),
    df_replications.time_to_failure,
    xlabel = "Number of repairers",
    ylabel = "Time to failure",
    title = "Ross model: time to failure distribution",
    label = "Replications",
)

savefig(p_box, plotsdir("ross_params_ttf_distribution.png"))

println()
println("Parameterized Ross model experiment completed.")
println("Saved data:")
println("  data/ross_params_replications.csv")
println("  data/ross_params_summary.csv")
println("  data/ross_params_analytics.csv")
println("  data/ross_params_sample_history.csv")
println("  data/ross_params_mttf_compare.csv")
println("Saved plots:")
println("  plots/ross_params_mttf.png")
println("  plots/ross_params_queue.png")
println("  plots/ross_params_utilization.png")
println("  plots/ross_params_ttf_distribution.png")
