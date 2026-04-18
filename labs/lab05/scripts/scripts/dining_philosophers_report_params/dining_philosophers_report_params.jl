using DrWatson
@quickactivate "project"

using DataFrames
using CSV
using Plots

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

param_sets = [
    (N = 4, tmax = 20.0),
    (N = 5, tmax = 30.0),
    (N = 6, tmax = 40.0),
]

summary = DataFrame(
    N = Int[],
    tmax = Float64[],
    model = String[],
    deadlock = Bool[],
    n_records = Int[],
)

println("Запуск параметризованного построения итоговых отчётов...")

for p in param_sets
    N = p.N
    tmax = p.tmax

    println("="^60)
    println("Параметры: N = $N, tmax = $tmax")

    net_classic, u0_classic, _ = build_classical_network(N)
    df_classic = simulate_stochastic(net_classic, u0_classic, tmax)

    classic_csv = datadir("dining_classic_N$(N)_t$(Int(round(tmax))).csv")
    CSV.write(classic_csv, df_classic)

    deadlock_classic = detect_deadlock(df_classic, net_classic)

    push!(summary, (
        N,
        tmax,
        "classic",
        deadlock_classic,
        nrow(df_classic),
    ))

    net_arbiter, u0_arbiter, _ = build_arbiter_network(N)
    df_arbiter = simulate_stochastic(net_arbiter, u0_arbiter, tmax)

    arbiter_csv = datadir("dining_arbiter_N$(N)_t$(Int(round(tmax))).csv")
    CSV.write(arbiter_csv, df_arbiter)

    deadlock_arbiter = detect_deadlock(df_arbiter, net_arbiter)

    push!(summary, (
        N,
        tmax,
        "arbiter",
        deadlock_arbiter,
        nrow(df_arbiter),
    ))

    eat_cols = [Symbol("Eat_$i") for i in 1:N]

    p1 = plot(
        df_classic.time,
        Matrix(df_classic[:, eat_cols]),
        label = ["Ф $i" for i in 1:N],
        xlabel = "Время",
        ylabel = "Ест (1/0)",
        title = "Классическая сеть, N = $N, tmax = $tmax",
    )

    p2 = plot(
        df_arbiter.time,
        Matrix(df_arbiter[:, eat_cols]),
        label = ["Ф $i" for i in 1:N],
        xlabel = "Время",
        ylabel = "Ест (1/0)",
        title = "Сеть с арбитром, N = $N, tmax = $tmax",
    )

    p_final = plot(p1, p2, layout = (2, 1), size = (900, 700))

    report_name = "final_report_N$(N)_t$(Int(round(tmax))).png"
    savefig(p_final, plotsdir(report_name))

    println("Сохранён рисунок: ", plotsdir(report_name))
end

summary_file = datadir("summary_dining_philosophers_report.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Итоговая таблица:")
println(summary)

println("Готово.")
println("Сводная таблица сохранена в: ", summary_file)
println("Итоговые рисунки сохранены в папке plots/")
