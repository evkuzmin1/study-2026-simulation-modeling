using DrWatson
@quickactivate "project"

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, states = build_sir_network(β, γ)

df = simulate_deterministic(
    net,
    u0,
    (0.0, tmax),
    saveat = 0.2,
    rates = [β, γ],
)

anim = @animate for i in 1:nrow(df)
    values = [df.S[i], df.I[i], df.R[i]]

    bar(
        string.(states),
        values,
        ylim = (0, 1000),
        xlabel = "State",
        ylabel = "Population",
        title = "SIR dynamics, t = $(round(df.time[i], digits = 1))",
        legend = false,
    )
end

gif(anim, plotsdir("sir_animation.gif"), fps = 20)

println("Анимация сохранена в plots/sir_animation.gif")
