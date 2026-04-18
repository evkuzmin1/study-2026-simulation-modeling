using DrWatson
@quickactivate "project"

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

using Plots
using DataFrames

N = 3
tmax = 30.0
fps = 5

println("Запуск анимации для классической сети Петри...")

net, u0, place_names = build_classical_network(N)
df = simulate_stochastic(net, u0, tmax)

anim = @animate for k in 1:nrow(df)
    values = [df[k, String(name)] for name in place_names]

    bar(
        string.(place_names),
        values;
        xlabel = "Позиции сети Петри",
        ylabel = "Число фишек",
        title = "Маркировка сети Петри, t = $(round(df[k, :time], digits=2))",
        legend = false,
        xticks = :all,
        xrotation = 45,
        size = (1000, 500)
    )
end

gif(anim, plotsdir("philosophers_simulation.gif"), fps = fps)

println("Анимация сохранена в plots/philosophers_simulation.gif")
