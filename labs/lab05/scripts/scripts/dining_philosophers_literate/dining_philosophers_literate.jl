using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

N = 5
tmax = 50.0

println("Запуск классической сети Петри...")

net_classic, u0_classic, _ = build_classical_network(N)

df_classic = simulate_stochastic(net_classic, u0_classic, tmax)
CSV.write(datadir("dining_classic.csv"), df_classic)

deadlock_classic = detect_deadlock(df_classic, net_classic)
println("Deadlock обнаружен (классическая сеть): ", deadlock_classic)

p_classic = plot_marking_evolution(df_classic, N)
savefig(p_classic, plotsdir("classic_simulation.png"))

println("Запуск сети Петри с арбитром...")

net_arbiter, u0_arbiter, _ = build_arbiter_network(N)

df_arbiter = simulate_stochastic(net_arbiter, u0_arbiter, tmax)
CSV.write(datadir("dining_arbiter.csv"), df_arbiter)

deadlock_arbiter = detect_deadlock(df_arbiter, net_arbiter)
println("Deadlock обнаружен (сеть с арбитром): ", deadlock_arbiter)

p_arbiter = plot_marking_evolution(df_arbiter, N)
savefig(p_arbiter, plotsdir("arbiter_simulation.png"))

println("Готово.")
println("CSV сохранены в папке data/")
println("Графики сохранены в папке plots/")
