using DrWatson
@quickactivate "project"

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots

β_range = 0.1:0.05:0.8
tmax = 100.0

gamma_sets = [
    (
        name = "gamma_low",
        γ = 0.05,
        description = "Медленное выздоровление",
    ),
    (
        name = "gamma_base",
        γ = 0.1,
        description = "Базовое выздоровление",
    ),
    (
        name = "gamma_high",
        γ = 0.2,
        description = "Быстрое выздоровление",
    ),
]

summary = DataFrame(
    scenario = String[],
    gamma = Float64[],
    β = Float64[],
    peak_I = Float64[],
    final_R = Float64[],
)

println("Запуск параметризованного сканирования β...")

for scenario in gamma_sets
    println("="^60)
    println("Сценарий: ", scenario.description)
    println("γ = ", scenario.γ)

    results = []

    for β in β_range
        net, u0, _ = build_sir_network(β, scenario.γ)

        df = simulate_deterministic(
            net,
            u0,
            (0.0, tmax),
            saveat = 0.5,
            rates = [β, scenario.γ],
        )

        peak_I = maximum(df.I)
        final_R = df.R[end]

        push!(
            results,
            (
                β = Float64(β),
                peak_I = Float64(peak_I),
                final_R = Float64(final_R),
            ),
        )

        push!(
            summary,
            (
                scenario.name,
                Float64(scenario.γ),
                Float64(β),
                Float64(peak_I),
                Float64(final_R),
            ),
        )
    end

    df_scan = DataFrame(results)

    csv_file = datadir("sir_scan_$(scenario.name).csv")
    CSV.write(csv_file, df_scan)

    p = plot(
        df_scan.β,
        [df_scan.peak_I df_scan.final_R],
        label = ["Peak I" "Final R"],
        marker = :circle,
        xlabel = "β (infection rate)",
        ylabel = "Population",
        title = "$(scenario.description), γ = $(scenario.γ)",
        linewidth = 2,
    )

    fig_file = plotsdir("sir_scan_$(scenario.name).png")
    savefig(p, fig_file)

    println("Сохранено:")
    println("  ", csv_file)
    println("  ", fig_file)
end

summary_file = datadir("sir_scan_params_summary.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Параметризованное сканирование завершено.")
println("Сводная таблица сохранена в: ", summary_file)
println("Рисунки сохранены в каталог: ", plotsdir())
