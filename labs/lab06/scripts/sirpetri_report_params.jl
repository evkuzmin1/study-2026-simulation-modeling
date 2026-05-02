using DrWatson
@quickactivate "project"

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots, Random

println("Запуск параметризованного отчётного скрипта...")

# ============================================================
# 1. ГРАФИКИ ТИПА COMPARISON
# ============================================================
# Здесь строятся два графика:
# - сравнение для сценария быстрого выздоровления
# - сравнение для сценария пониженного заражения

comparison_sets = [
    (
        name = "fast_recovery",
        β = 0.3,
        γ = 0.2,
        tmax = 100.0,
        seed = 123,
        title = "Comparison: fast recovery",
    ),
    (
        name = "low_infection",
        β = 0.15,
        γ = 0.1,
        tmax = 100.0,
        seed = 124,
        title = "Comparison: low infection",
    ),
]

comparison_summary = DataFrame(
    scenario = String[],
    β = Float64[],
    γ = Float64[],
    peak_I_det = Float64[],
    peak_I_stoch = Float64[],
    final_R_det = Float64[],
    final_R_stoch = Float64[],
)

for params in comparison_sets
    net, u0, _ = build_sir_network(params.β, params.γ)

    df_det = simulate_deterministic(
        net,
        u0,
        (0.0, params.tmax),
        saveat = 0.5,
        rates = [params.β, params.γ],
    )

    Random.seed!(params.seed)
    df_stoch = simulate_stochastic(
        net,
        u0,
        (0.0, params.tmax),
        rates = [params.β, params.γ],
    )

    p = plot(
        df_det.time,
        df_det.I,
        label = "Deterministic I",
        xlabel = "Time",
        ylabel = "Infected",
        title = params.title,
        linewidth = 2,
    )

    plot!(
        p,
        df_stoch.time,
        df_stoch.I,
        label = "Stochastic I",
        linewidth = 2,
    )

    savefig(plotsdir("comparison_$(params.name).png"))

    push!(
        comparison_summary,
        (
            params.name,
            params.β,
            params.γ,
            maximum(df_det.I),
            maximum(df_stoch.I),
            df_det.R[end],
            df_stoch.R[end],
        ),
    )
end

CSV.write(datadir("comparison_summary.csv"), comparison_summary)

# ============================================================
# 2. ГРАФИКИ ТИПА SENSITIVITY
# ============================================================
# Здесь строятся два графика чувствительности:
# - при медленном выздоровлении γ = 0.05
# - при быстром выздоровлении γ = 0.2

β_range = 0.1:0.05:0.8

sensitivity_sets = [
    (
        name = "gamma_low",
        γ = 0.05,
        tmax = 100.0,
        title = "Sensitivity: gamma = 0.05",
    ),
    (
        name = "gamma_high",
        γ = 0.2,
        tmax = 100.0,
        title = "Sensitivity: gamma = 0.2",
    ),
]

sensitivity_summary = DataFrame(
    case_name = String[],
    β = Float64[],
    γ = Float64[],
    peak_I = Float64[],
    final_R = Float64[],
)

for params in sensitivity_sets
    results = []

    for β in β_range
        net, u0, _ = build_sir_network(β, params.γ)

        df = simulate_deterministic(
            net,
            u0,
            (0.0, params.tmax),
            saveat = 0.5,
            rates = [β, params.γ],
        )

        peak_I = maximum(df.I)
        final_R = df.R[end]

        push!(results, (β = β, peak_I = peak_I, final_R = final_R))
        push!(sensitivity_summary, (params.name, β, params.γ, peak_I, final_R))
    end

    df_scan = DataFrame(results)

    p = plot(
        df_scan.β,
        df_scan.peak_I,
        marker = :circle,
        xlabel = "β",
        ylabel = "Peak I",
        title = params.title,
        label = "Peak I",
    )

    savefig(plotsdir("sensitivity_$(params.name).png"))
end

CSV.write(datadir("sensitivity_summary.csv"), sensitivity_summary)

println("Отчётные параметризованные графики сохранены в plots/")
println("Созданы файлы:")
println(" - plots/comparison_fast_recovery.png")
println(" - plots/comparison_low_infection.png")
println(" - plots/sensitivity_gamma_low.png")
println(" - plots/sensitivity_gamma_high.png")
println("Также сохранены таблицы:")
println(" - data/comparison_summary.csv")
println(" - data/sensitivity_summary.csv")
