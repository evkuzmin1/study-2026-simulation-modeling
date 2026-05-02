using DrWatson
@quickactivate "project"

using Random

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots

mkpath(datadir("params"))
mkpath(plotsdir("params"))

param_sets = [
    (
        name = "baseline",
        β = 0.3,
        γ = 0.1,
        tmax = 100.0,
        seed = 123,
        description = "Базовый сценарий",
    ),
    (
        name = "fast_recovery",
        β = 0.3,
        γ = 0.3,
        tmax = 100.0,
        seed = 124,
        description = "Более быстрое выздоровление",
    ),
    (
        name = "lower_infection",
        β = 0.1,
        γ = 0.1,
        tmax = 100.0,
        seed = 125,
        description = "Меньшая интенсивность заражения",
    ),
]

summary = DataFrame(
    scenario = String[],
    β = Float64[],
    γ = Float64[],
    tmax = Float64[],
    model = String[],
    final_S = Float64[],
    final_I = Float64[],
    final_R = Float64[],
    n_records = Int[],
)

println("Запуск параметризованного моделирования SIR...")

for p in param_sets
    println("="^60)
    println("Сценарий: ", p.description)
    println("β = $(p.β), γ = $(p.γ), tmax = $(p.tmax)")

    net, u0, states = build_sir_network(p.β, p.γ)

    df_det = simulate_deterministic(
        net,
        u0,
        (0.0, p.tmax),
        saveat = 0.5,
        rates = [p.β, p.γ],
    )

    det_file = datadir("params", "sir_det_$(p.name).csv")
    CSV.write(det_file, df_det)

    push!(
        summary,
        (
            p.name,
            p.β,
            p.γ,
            p.tmax,
            "deterministic",
            Float64(df_det.S[end]),
            Float64(df_det.I[end]),
            Float64(df_det.R[end]),
            nrow(df_det),
        ),
    )

    Random.seed!(p.seed)

    df_stoch = simulate_stochastic(
        net,
        u0,
        (0.0, p.tmax),
        rates = [p.β, p.γ],
    )

    stoch_file = datadir("params", "sir_stoch_$(p.name).csv")
    CSV.write(stoch_file, df_stoch)

    push!(
        summary,
        (
            p.name,
            p.β,
            p.γ,
            p.tmax,
            "stochastic",
            Float64(df_stoch.S[end]),
            Float64(df_stoch.I[end]),
            Float64(df_stoch.R[end]),
            nrow(df_stoch),
        ),
    )

    p_det = plot_sir(df_det)
    title!(p_det, "Детерминированная модель")

    p_stoch = plot_sir(df_stoch)
    title!(p_stoch, "Стохастическая модель")

    p_final = plot(
        p_det,
        p_stoch;
        layout = (1, 2),
        size = (1100, 450),
        plot_title = "$(p.description): β=$(p.β), γ=$(p.γ)",
    )

    fig_file = plotsdir("params", "sir_compare_$(p.name).png")
    savefig(p_final, fig_file)

    println("Сохранено:")
    println("  ", det_file)
    println("  ", stoch_file)
    println("  ", fig_file)
end

summary_file = datadir("params", "sir_params_summary.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Параметризованное моделирование завершено.")
println("Сводная таблица сохранена в: ", summary_file)
println("Итоговые рисунки сохранены в: ", plotsdir("params"))
