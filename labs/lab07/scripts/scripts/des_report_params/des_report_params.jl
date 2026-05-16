using DrWatson
@quickactivate "project"

using DataFrames
using CSV
using Plots
using Statistics

mmc_params = CSV.read(datadir("mmc_params_compare.csv"), DataFrame)
ross_params = CSV.read(datadir("ross_params_summary.csv"), DataFrame)
ross_mttf_compare = CSV.read(datadir("ross_params_mttf_compare.csv"), DataFrame)

mmc_resource = mmc_params.num_servers
mmc_waiting = mmc_params.avg_waiting_time_mean
mmc_queue = mmc_params.max_queue_length_mean
mmc_utilization = mmc_params.utilization_mean

mmc_waiting_norm = mmc_waiting ./ mmc_waiting[1]
mmc_queue_norm = mmc_queue ./ mmc_queue[1]
mmc_utilization_norm = mmc_utilization ./ mmc_utilization[1]

ross_resource = ross_params.num_repairers
ross_mttf = ross_params.mean_time_to_failure
ross_queue = ross_params.mean_repair_queue
ross_utilization = ross_params.mean_repairer_utilization

ross_mttf_inverse_norm = ross_mttf[1] ./ ross_mttf
ross_queue_norm = ross_queue ./ ross_queue[1]
ross_utilization_norm = ross_utilization ./ ross_utilization[1]

summary_before_after = DataFrame(
    model = [
        "M/M/c",
        "M/M/c",
        "M/M/c",
        "Ross model",
        "Ross model",
        "Ross model",
    ],
    metric = [
        "Average waiting time",
        "Average max queue length",
        "Server utilization",
        "Mean time to failure",
        "Mean repair queue",
        "Repairer utilization",
    ],
    initial_resource = [
        mmc_resource[1],
        mmc_resource[1],
        mmc_resource[1],
        ross_resource[1],
        ross_resource[1],
        ross_resource[1],
    ],
    final_resource = [
        mmc_resource[end],
        mmc_resource[end],
        mmc_resource[end],
        ross_resource[end],
        ross_resource[end],
        ross_resource[end],
    ],
    initial_value = [
        mmc_waiting[1],
        mmc_queue[1],
        mmc_utilization[1],
        ross_mttf[1],
        ross_queue[1],
        ross_utilization[1],
    ],
    final_value = [
        mmc_waiting[end],
        mmc_queue[end],
        mmc_utilization[end],
        ross_mttf[end],
        ross_queue[end],
        ross_utilization[end],
    ],
)

summary_before_after.relative_change = (
    summary_before_after.final_value .-
    summary_before_after.initial_value
) ./ summary_before_after.initial_value

CSV.write(datadir("des_params_before_after.csv"), summary_before_after)

mmc_normalized = DataFrame(
    num_servers = mmc_resource,
    waiting_time_norm = mmc_waiting_norm,
    queue_norm = mmc_queue_norm,
    utilization_norm = mmc_utilization_norm,
)

CSV.write(datadir("des_params_mmc_normalized.csv"), mmc_normalized)

ross_normalized = DataFrame(
    num_repairers = ross_resource,
    mttf_inverse_norm = ross_mttf_inverse_norm,
    queue_norm = ross_queue_norm,
    utilization_norm = ross_utilization_norm,
)

CSV.write(datadir("des_params_ross_normalized.csv"), ross_normalized)

mmc_efficiency_index = (
    mmc_waiting_norm .+
    mmc_queue_norm
) ./ 2

ross_efficiency_index = (
    ross_mttf_inverse_norm .+
    ross_queue_norm
) ./ 2

efficiency_summary = DataFrame(
    model = [
        fill("M/M/c", length(mmc_resource));
        fill("Ross model", length(ross_resource))
    ],
    resource_count = [
        mmc_resource;
        ross_resource
    ],
    efficiency_index = [
        mmc_efficiency_index;
        ross_efficiency_index
    ],
)

CSV.write(datadir("des_params_efficiency_index.csv"), efficiency_summary)

p_mmc_norm = plot(
    mmc_resource,
    mmc_waiting_norm,
    marker = :circle,
    xlabel = "Number of servers",
    ylabel = "Normalized value",
    title = "M/M/c: normalized improvement",
    label = "Waiting time",
    linewidth = 2,
)

plot!(
    p_mmc_norm,
    mmc_resource,
    mmc_queue_norm,
    marker = :circle,
    label = "Queue length",
    linewidth = 2,
)

plot!(
    p_mmc_norm,
    mmc_resource,
    mmc_utilization_norm,
    marker = :circle,
    label = "Utilization",
    linewidth = 2,
)

savefig(p_mmc_norm, plotsdir("des_params_mmc_normalized.png"))

p_ross_norm = plot(
    ross_resource,
    ross_mttf_inverse_norm,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Normalized value",
    title = "Ross model: normalized improvement",
    label = "MTTF inverse",
    linewidth = 2,
)

plot!(
    p_ross_norm,
    ross_resource,
    ross_queue_norm,
    marker = :circle,
    label = "Repair queue",
    linewidth = 2,
)

plot!(
    p_ross_norm,
    ross_resource,
    ross_utilization_norm,
    marker = :circle,
    label = "Repairer utilization",
    linewidth = 2,
)

savefig(p_ross_norm, plotsdir("des_params_ross_normalized.png"))

p_efficiency = plot(
    mmc_resource,
    mmc_efficiency_index,
    marker = :circle,
    xlabel = "Resource count",
    ylabel = "Efficiency index",
    title = "DES models: normalized efficiency index",
    label = "M/M/c",
    linewidth = 2,
)

plot!(
    p_efficiency,
    ross_resource,
    ross_efficiency_index,
    marker = :circle,
    label = "Ross model",
    linewidth = 2,
)

savefig(p_efficiency, plotsdir("des_params_efficiency_index.png"))

x_change = collect(1:nrow(summary_before_after))

labels_change = string.(
    summary_before_after.model,
    ": ",
    summary_before_after.metric,
)

p_change = bar(
    x_change,
    summary_before_after.relative_change,
    xlabel = "Metric",
    ylabel = "Relative change",
    title = "DES models: relative change from initial to final scenario",
    label = "Relative change",
    xticks = (x_change, labels_change),
    xrotation = 35,
)

savefig(p_change, plotsdir("des_params_relative_change.png"))

println("Parameterized DES report completed.")

println()
println("Saved data:")
println("  data/des_params_before_after.csv")
println("  data/des_params_mmc_normalized.csv")
println("  data/des_params_ross_normalized.csv")
println("  data/des_params_efficiency_index.csv")

println()
println("Saved plots:")
println("  plots/des_params_mmc_normalized.png")
println("  plots/des_params_ross_normalized.png")
println("  plots/des_params_efficiency_index.png")
println("  plots/des_params_relative_change.png")
