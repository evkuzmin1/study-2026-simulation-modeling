using DrWatson
@quickactivate "project"

include(srcdir("sir_model.jl"))
using .SIRModel

using CSV
using DataFrames
using Plots
using Statistics
using Literate

base_S0 = 990
base_I0 = 10
base_R0 = 0
base_tmax = 100.0

base_beta = 0.05
base_c = 10.0
base_gamma = 0.25

replications = 5

scenarios = DataFrame(
    scenario = String[],
    beta = Float64[],
    c = Float64[],
    gamma = Float64[],
)

for beta in [0.03, 0.05, 0.07]
    push!(
        scenarios,
        (
            scenario = "beta_scan",
            beta = beta,
            c = base_c,
            gamma = base_gamma,
        ),
    )
end

for c in [6.0, 10.0, 14.0]
    push!(
        scenarios,
        (
            scenario = "contact_scan",
            beta = base_beta,
            c = c,
            gamma = base_gamma,
        ),
    )
end

for gamma in [0.15, 0.25, 0.35]
    push!(
        scenarios,
        (
            scenario = "gamma_scan",
            beta = base_beta,
            c = base_c,
            gamma = gamma,
        ),
    )
end

all_results = DataFrame()
all_summaries = DataFrame()

for (scenario_id, row) in enumerate(eachrow(scenarios))
    for replication in 1:replications
        seed = 1000 + 100 * scenario_id + replication

        params = SIRParameters(
            base_S0,
            base_I0,
            base_R0,
            row.beta,
            row.c,
            row.gamma,
            base_tmax,
            seed,
        )

        result = simulate_sir_des(params)

        df_result = result_dataframe(result)
        df_summary = summary_dataframe(result)

        df_result.scenario .= row.scenario
        df_result.beta .= row.beta
        df_result.c .= row.c
        df_result.gamma .= row.gamma
        df_result.replication .= replication
        df_result.seed .= seed

        df_summary.scenario .= row.scenario
        df_summary.replication .= replication

        append!(all_results, df_result)
        append!(all_summaries, df_summary)
    end
end

summary_by_scenario = combine(
    groupby(all_summaries, [:scenario, :beta, :c, :gamma]),
    :reproduction_number => mean => :mean_reproduction_number,
    :peak_I => mean => :mean_peak_I,
    :peak_I => std => :std_peak_I,
    :peak_time => mean => :mean_peak_time,
    :final_size => mean => :mean_final_size,
    :final_size => std => :std_final_size,
    :events_count => mean => :mean_events_count,
)

CSV.write(datadir("sir_des_params_results.csv"), all_results)
CSV.write(datadir("sir_des_params_summaries.csv"), all_summaries)
CSV.write(datadir("sir_des_params_summary_by_scenario.csv"), summary_by_scenario)

println("SIR DES parameter scan summary:")
println(summary_by_scenario)

beta_summary = filter(row -> row.scenario == "beta_scan", summary_by_scenario)
contact_summary = filter(row -> row.scenario == "contact_scan", summary_by_scenario)
gamma_summary = filter(row -> row.scenario == "gamma_scan", summary_by_scenario)

CSV.write(datadir("sir_des_params_beta_summary.csv"), beta_summary)
CSV.write(datadir("sir_des_params_contact_summary.csv"), contact_summary)
CSV.write(datadir("sir_des_params_gamma_summary.csv"), gamma_summary)

p_beta = plot(
    beta_summary.beta,
    beta_summary.mean_peak_I,
    marker = :circle,
    label = "Mean peak I",
    xlabel = "Beta",
    ylabel = "Peak infected",
    title = "SIR DES: effect of beta on infection peak",
    linewidth = 2,
)

savefig(p_beta, plotsdir("sir_des_params_beta_peak.png"))

p_contact = plot(
    contact_summary.c,
    contact_summary.mean_peak_I,
    marker = :circle,
    label = "Mean peak I",
    xlabel = "Average contacts",
    ylabel = "Peak infected",
    title = "SIR DES: effect of contacts on infection peak",
    linewidth = 2,
)

savefig(p_contact, plotsdir("sir_des_params_contacts_peak.png"))

p_gamma = plot(
    gamma_summary.gamma,
    gamma_summary.mean_peak_I,
    marker = :circle,
    label = "Mean peak I",
    xlabel = "Gamma",
    ylabel = "Peak infected",
    title = "SIR DES: effect of gamma on infection peak",
    linewidth = 2,
)

savefig(p_gamma, plotsdir("sir_des_params_gamma_peak.png"))

summary_labels = string.(
    summary_by_scenario.scenario,
    "\nβ=",
    summary_by_scenario.beta,
    ", c=",
    summary_by_scenario.c,
    ", γ=",
    summary_by_scenario.gamma,
)

x_positions = collect(1:nrow(summary_by_scenario))

p_final_size = bar(
    x_positions,
    summary_by_scenario.mean_final_size,
    label = "Mean final size",
    xlabel = "Scenario",
    ylabel = "Final size",
    title = "SIR DES: final epidemic size by scenario",
    xticks = (x_positions, summary_labels),
    xrotation = 35,
)

savefig(p_final_size, plotsdir("sir_des_params_final_size.png"))

println()
println("SIR DES parameter scan completed.")
println("Saved data:")
println("  data/sir_des_params_results.csv")
println("  data/sir_des_params_summaries.csv")
println("  data/sir_des_params_summary_by_scenario.csv")
println("  data/sir_des_params_beta_summary.csv")
println("  data/sir_des_params_contact_summary.csv")
println("  data/sir_des_params_gamma_summary.csv")
println("Saved plots:")
println("  plots/sir_des_params_beta_peak.png")
println("  plots/sir_des_params_contacts_peak.png")
println("  plots/sir_des_params_gamma_peak.png")
println("  plots/sir_des_params_final_size.png")

output_dir = scriptsdir("generated", "sir_des_params")
mkpath(output_dir)

Literate.script(@__FILE__, output_dir)
Literate.notebook(@__FILE__, output_dir)
Literate.markdown(@__FILE__, output_dir; flavor = Literate.QuartoFlavor())

println()
println("Generated parameterized literate outputs:")
println("  scripts/generated/sir_des_params/")
