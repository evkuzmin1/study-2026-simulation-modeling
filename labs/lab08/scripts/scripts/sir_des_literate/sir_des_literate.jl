using DrWatson
@quickactivate "project"

include(srcdir("sir_model.jl"))
using .SIRModel

using CSV
using DataFrames
using Plots
using Literate

params = SIRParameters(
    990,     # начальное число восприимчивых
    10,      # начальное число инфицированных
    0,       # начальное число выздоровевших
    0.05,    # вероятность передачи инфекции
    10.0,    # среднее число контактов
    0.25,    # интенсивность выздоровления
    100.0,   # максимальное время моделирования
    123,     # seed
)

R0_value = sir_basic_reproduction_number(params)

println("Basic reproduction number R0 = ", R0_value)

result = simulate_sir_des(params)

df_result = result_dataframe(result)
df_events = events_dataframe(result)
df_summary = summary_dataframe(result)

CSV.write(datadir("sir_des_literate.csv"), df_result)
CSV.write(datadir("sir_des_literate_events.csv"), df_events)
CSV.write(datadir("sir_des_literate_summary.csv"), df_summary)

println("SIR DES literate summary:")
println(df_summary)

p_dynamics = plot(
    df_result.t,
    [df_result.S df_result.I df_result.R],
    label = ["S" "I" "R"],
    xlabel = "Time",
    ylabel = "Population",
    title = "SIR DES dynamics",
    linewidth = 2,
)

savefig(p_dynamics, plotsdir("sir_des_literate_dynamics.png"))

p_infected = plot(
    df_result.t,
    df_result.I,
    label = "Infected",
    xlabel = "Time",
    ylabel = "Infected",
    title = "SIR DES infected dynamics",
    linewidth = 2,
)

savefig(p_infected, plotsdir("sir_des_literate_infected.png"))

final_state = DataFrame(
    group = ["S", "I", "R"],
    value = [
        df_result.S[end],
        df_result.I[end],
        df_result.R[end],
    ],
)

CSV.write(datadir("sir_des_literate_final_state.csv"), final_state)

p_final = bar(
    final_state.group,
    final_state.value,
    label = "Final state",
    xlabel = "Group",
    ylabel = "Population",
    title = "SIR DES final state",
)

savefig(p_final, plotsdir("sir_des_literate_final_state.png"))

println()
println("SIR DES literate simulation completed.")
println("Saved data:")
println("  data/sir_des_literate.csv")
println("  data/sir_des_literate_events.csv")
println("  data/sir_des_literate_summary.csv")
println("  data/sir_des_literate_final_state.csv")
println("Saved plots:")
println("  plots/sir_des_literate_dynamics.png")
println("  plots/sir_des_literate_infected.png")
println("  plots/sir_des_literate_final_state.png")

output_dir = scriptsdir("generated", "sir_des_literate")
mkpath(output_dir)

Literate.script(@__FILE__, output_dir)
Literate.notebook(@__FILE__, output_dir)
Literate.markdown(@__FILE__, output_dir; flavor = Literate.QuartoFlavor())

println()
println("Generated literate outputs:")
println("  scripts/generated/sir_des_literate/")
