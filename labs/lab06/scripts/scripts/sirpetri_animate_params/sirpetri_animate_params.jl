using DrWatson
@quickactivate "project"

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots

param_sets = [
    (
        name = "baseline",
        β = 0.3,
        γ = 0.1,
        tmax = 60.0,
        title = "Базовый сценарий",
    ),
    (
        name = "fast_recovery",
        β = 0.3,
        γ = 0.3,
        tmax = 60.0,
        title = "Быстрое выздоровление",
    ),
    (
        name = "lower_infection",
        β = 0.1,
        γ = 0.1,
        tmax = 60.0,
        title = "Меньшая интенсивность заражения",
    ),
]

summary = DataFrame(
    scenario = String[],
    β = Float64[],
    γ = Float64[],
    tmax = Float64[],
    peak_I = Float64[],
    final_S = Float64[],
    final_I = Float64[],
    final_R = Float64[],
    gif_file = String[],
)

println("Запуск параметризованного построения анимаций SIR...")

for params in param_sets
    println("="^60)
    println("Сценарий: ", params.title)
    println("β = $(params.β), γ = $(params.γ), tmax = $(params.tmax)")

    net, u0, states = build_sir_network(params.β, params.γ)

    df = simulate_deterministic(
        net,
        u0,
        (0.0, params.tmax),
        saveat = 0.2,
        rates = [params.β, params.γ],
    )

    anim = @animate for i in 1:nrow(df)
        values = [df.S[i], df.I[i], df.R[i]]

        bar(
            string.(states),
            values,
            ylim = (0, 1000),
            xlabel = "State",
            ylabel = "Population",
            title = "$(params.title), t = $(round(df.time[i], digits = 1))",
            legend = false,
        )
    end

    gif_path = plotsdir("sir_animation_$(params.name).gif")
    gif(anim, gif_path, fps = 20)

    push!(
        summary,
        (
            params.name,
            Float64(params.β),
            Float64(params.γ),
            Float64(params.tmax),
            Float64(maximum(df.I)),
            Float64(df.S[end]),
            Float64(df.I[end]),
            Float64(df.R[end]),
            gif_path,
        ),
    )

    println("Анимация сохранена в: ", gif_path)
end

summary_file = datadir("sir_animation_params_summary.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Параметризованное построение анимаций завершено.")
println("Сводная таблица сохранена в: ", summary_file)
