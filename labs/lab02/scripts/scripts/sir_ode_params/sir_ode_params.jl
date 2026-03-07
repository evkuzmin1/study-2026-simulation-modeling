using DrWatson
@quickactivate "project"

using DifferentialEquations
using SimpleDiffEq
using Tables
using DataFrames
using StatsPlots
using LaTeXStrings
using Plots
using BenchmarkTools

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

function sir_ode!(du, u, p, t)
    S, I, R = u
    β, c, γ = p
    N = S + I + R

    @inbounds begin
        du[1] = -β * c * I / N * S
        du[2] = β * c * I / N * S - γ * I
        du[3] = γ * I
    end
    return nothing
end

δt = 0.1
tmax = 40.0
tspan = (0.0, tmax)
u0 = [990.0, 10.0, 0.0]   # S, I, R

β_values = [0.03, 0.05, 0.07]

for β in β_values
    println("\n===== Расчет для β = ", β, " =====")

    p = [β, 10.0, 0.25]   # β, c, γ
    R0 = (p[2] * p[1]) / p[3]

    println("Параметры модели SIR:")
    println("β (вероятность заражения) = ", p[1])
    println("c (среднее число контактов) = ", p[2])
    println("γ (скорость выздоровления) = ", p[3])
    println("R0 = c * β / γ = ", round(R0, digits=3))
    println("Средняя продолжительность болезни = ", round(1 / p[3], digits=2), " дней")
    println("Начальные условия: S0 = ", u0[1], ", I0 = ", u0[2], ", R0 = ", u0[3])

    prob_ode = ODEProblem(sir_ode!, u0, tspan, p)
    sol_ode = solve(prob_ode, dt = δt)

    df_ode = DataFrame(Tables.table(sol_ode'))
    rename!(df_ode, ["S", "I", "R"])
    df_ode[!, :t] = sol_ode.t
    df_ode[!, :N] = df_ode.S + df_ode.I + df_ode.R

    peak_idx = argmax(df_ode.I)
    peak_time = df_ode.t[peak_idx]
    peak_value = df_ode.I[peak_idx]

    df_ode[!, :Re] = R0 .* df_ode.S ./ df_ode.N

    plt1 = @df df_ode plot(
        :t,
        [:S :I :R],
        label=[L"S(t)" L"I(t)" L"R(t)"],
        xlabel="Время, дни",
        ylabel="Количество людей",
        title="SIR модель (β=$(β), R0=$(round(R0, digits=2)))",
        linewidth=2,
        legend=:right,
        grid=true,
        size=(800, 500)
    )

    annotate!(
        plt1,
        maximum(df_ode.t) * 0.7,
        maximum(df_ode.N) * 0.8,
        text("β = $(p[1])\nc = $(p[2])\nγ = $(p[3])\nR0 = $(round(R0, digits=2))", 8, :left)
    )

    display(plt1)

    β_str = replace(string(β), "." => "_")
    savefig(plt1, plotsdir(script_name, "sir_beta_$(β_str).png"))

    println("\n=== АНАЛИЗ РЕЗУЛЬТАТОВ ===")
    println("Общая численность популяции (контроль): N = ", round(df_ode.N[1], digits=1))
    println("Пиковое число зараженных: I_max = ", round(peak_value, digits=1))
    println("Время достижения пика: t_peak = ", round(peak_time, digits=1), " дней")
    println("Итоговое число переболевших: R(∞) = ", round(df_ode.R[end], digits=1))
    println("Доля переболевших: ", round(df_ode.R[end] / df_ode.N[1] * 100, digits=1), "%")

    if R0 > 1
        println("\nТеоретический анализ:")
        println("- Порог коллективного иммунитета: ", round((1 - 1 / R0) * 100, digits=1), "%")
        println("- Теоретический пик при S/N = 1/R0 = ", round(1 / R0, digits=3))
    end
end
