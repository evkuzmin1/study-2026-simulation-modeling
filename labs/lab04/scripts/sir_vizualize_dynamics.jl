using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV

include(srcdir("sir_model.jl"))

# Загружаем результаты сканирования
df = CSV.read(datadir("beta_scan_all.csv"), DataFrame)

# Первый график: пик и конечная доля инфицированных
p1 = plot(
    df.beta,
    df.peak,
    label = "Пик",
    xlabel = "β",
    ylabel = "Доля инфицированных",
)

plot!(
    p1,
    df.beta,
    df.final_inf,
    label = "Конечная",
)

# Второй график: число умерших
p2 = plot(
    df.beta,
    df.deaths,
    xlabel = "β",
    ylabel = "Число умерших",
    label = "Умершие",
)

# Третий график: доля выздоровевших
p3 = plot(
    df.beta,
    df.final_rec,
    xlabel = "β",
    ylabel = "Доля выздоровевших",
    label = "Выздоровевшие",
)

# Составной график
plot(
    p1,
    p2,
    p3,
    layout = (3, 1),
    size = (800, 900),
)

savefig(plotsdir("comprehensive_analysis.png"))
