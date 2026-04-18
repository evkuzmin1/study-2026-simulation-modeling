using DrWatson
@quickactivate "project"

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

using Plots
using DataFrames

param_sets = [
    (N = 3, tmax = 20.0, fps = 5),
    (N = 4, tmax = 25.0, fps = 5),
    (N = 5, tmax = 30.0, fps = 5),
]

println("Запуск параметризованной генерации GIF-анимаций...")

for p in param_sets
    N = p.N
    tmax = p.tmax
    fps = p.fps

    println("Создание анимации: N = $N, tmax = $tmax, fps = $fps")

    net, u0, place_names = build_classical_network(N)
    df = simulate_stochastic(net, u0, tmax)

    anim = @animate for k in 1:nrow(df)
        values = [df[k, String(name)] for name in place_names]

        bar(
            string.(place_names),
            values;
            xlabel = "Позиции сети Петри",
            ylabel = "Число фишек",
            title = "Маркировка сети Петри, N = $N, t = $(round(df[k, :time], digits=2))",
            legend = false,
            xticks = :all,
            xrotation = 45,
            size = (1000, 500)
        )
    end

    filename = "philosophers_simulation_N$(N)_t$(Int(round(tmax))).gif"
    gif(anim, plotsdir(filename), fps = fps)

    println("Сохранено: ", plotsdir(filename))
end

println("Готово. Созданы 3 GIF-файла в папке plots/")
