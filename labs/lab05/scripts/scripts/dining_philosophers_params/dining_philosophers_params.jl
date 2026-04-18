using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

philosopher_counts = [3, 5, 7]
time_values = [30.0, 50.0]

mkpath(datadir("params"))
mkpath(plotsdir("params"))

summary = DataFrame(
    N = Int[],
    tmax = Float64[],
    model = String[],
    deadlock = Bool[],
    n_records = Int[]
)

for N in philosopher_counts
    for tmax in time_values
        println("="^60)
        println("Параметры: N = $N, tmax = $tmax")

        println("Запуск классической сети Петри...")
        net_classic, u0_classic, _ = build_classical_network(N)

        df_classic = simulate_stochastic(net_classic, u0_classic, tmax)

        classic_csv = datadir("params", "classic_N$(N)_t$(Int(round(tmax))).csv")
        CSV.write(classic_csv, df_classic)

        deadlock_classic = detect_deadlock(df_classic, net_classic)
        println("Deadlock обнаружен (классическая сеть): ", deadlock_classic)

        p_classic = plot_marking_evolution(df_classic, N)
        classic_plot = plotsdir("params", "classic_N$(N)_t$(Int(round(tmax))).png")
        savefig(p_classic, classic_plot)

        push!(summary, (
            N,
            tmax,
            "classic",
            deadlock_classic,
            nrow(df_classic)
        ))

        println("Запуск сети Петри с арбитром...")
        net_arbiter, u0_arbiter, _ = build_arbiter_network(N)

        df_arbiter = simulate_stochastic(net_arbiter, u0_arbiter, tmax)

        arbiter_csv = datadir("params", "arbiter_N$(N)_t$(Int(round(tmax))).csv")
        CSV.write(arbiter_csv, df_arbiter)

        deadlock_arbiter = detect_deadlock(df_arbiter, net_arbiter)
        println("Deadlock обнаружен (сеть с арбитром): ", deadlock_arbiter)

        p_arbiter = plot_marking_evolution(df_arbiter, N)
        arbiter_plot = plotsdir("params", "arbiter_N$(N)_t$(Int(round(tmax))).png")
        savefig(p_arbiter, arbiter_plot)

        push!(summary, (
            N,
            tmax,
            "arbiter",
            deadlock_arbiter,
            nrow(df_arbiter)
        ))
    end
end

summary_file = datadir("params", "summary_dining_philosophers.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Итоговая таблица:")
println(summary)

println("Готово.")
println("Параметризованные CSV сохранены в папке data/params/")
println("Параметризованные графики сохранены в папке plots/params/")
println("Сводка сохранена в файле: ", summary_file)
