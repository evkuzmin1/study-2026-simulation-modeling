using DrWatson
@quickactivate "project"

include(srcdir("sir_model.jl"))
using .SIRModel

using CSV
using DataFrames
using Plots

# Параметры базового запуска SIR-модели.
params = SIRParameters(
    990,     # S0
    10,      # I0
    0,       # R0
    0.05,    # beta
    10.0,    # c
    0.25,    # gamma
    100.0,   # tmax
    123,     # seed
)

# Запуск дискретно-событийной симуляции.
result = simulate_sir_des(params)

# Формирование таблиц результатов.
df_result = result_dataframe(result)
df_events = events_dataframe(result)
df_summary = summary_dataframe(result)

# Сохранение результатов в data/.
CSV.write(datadir("sir_des.csv"), df_result)
CSV.write(datadir("sir_des_events.csv"), df_events)
CSV.write(datadir("sir_des_summary.csv"), df_summary)

println("SIR DES summary:")
println(df_summary)

# График динамики S, I и R.
p_dynamics = plot(
    df_result.t,
    [df_result.S df_result.I df_result.R],
    label = ["S" "I" "R"],
    xlabel = "Time",
    ylabel = "Population",
    title = "SIR DES dynamics",
    linewidth = 2,
)

savefig(p_dynamics, plotsdir("sir_des_dynamics.png"))

# График только для числа инфицированных.
p_infected = plot(
    df_result.t,
    df_result.I,
    label = "Infected",
    xlabel = "Time",
    ylabel = "Infected",
    title = "SIR DES infected dynamics",
    linewidth = 2,
)

savefig(p_infected, plotsdir("sir_des_infected.png"))

# Столбчатая диаграмма итогового состояния.
final_state = DataFrame(
    group = ["S", "I", "R"],
    value = [
        df_result.S[end],
        df_result.I[end],
        df_result.R[end],
    ],
)

CSV.write(datadir("sir_des_final_state.csv"), final_state)

p_final = bar(
    final_state.group,
    final_state.value,
    label = "Final state",
    xlabel = "Group",
    ylabel = "Population",
    title = "SIR DES final state",
)

savefig(p_final, plotsdir("sir_des_final_state.png"))

println()
println("SIR DES simulation completed.")
println("Saved data:")
println("  data/sir_des.csv")
println("  data/sir_des_events.csv")
println("  data/sir_des_summary.csv")
println("  data/sir_des_final_state.csv")
println("Saved plots:")
println("  plots/sir_des_dynamics.png")
println("  plots/sir_des_infected.png")
println("  plots/sir_des_final_state.png")
