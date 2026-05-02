# # Лабораторная работа №6
# ## Параметризованная анимация SIR-модели в подходе сетей Петри
#
# В данном скрипте выполняется построение нескольких GIF-анимаций
# для SIR-модели, реализованной в подходе сетей Петри.
#
# Базовый скрипт `sirpetri_animate.jl` строит одну анимацию для одного
# набора параметров. В этой параметризованной версии рассматриваются
# три сценария:
#
# - базовый сценарий;
# - сценарий с более быстрым выздоровлением;
# - сценарий с меньшей интенсивностью заражения.
#
# Для каждого сценария строится отдельная GIF-анимация. Чтобы не
# перегружать отчёт и каталог результатов, создаются только три файла.

using DrWatson
@quickactivate "project"

# ## Подключение модели
#
# Основная реализация SIR-модели в подходе сетей Петри находится
# в файле `src/SIRPetri.jl`.

include(srcdir("SIRPetri.jl"))
using .SIRPetri

using DataFrames, CSV, Plots

# ## Наборы параметров
#
# Для сравнения выбраны три сценария:
#
# 1. базовый вариант из основного скрипта;
# 2. вариант с более быстрым выздоровлением;
# 3. вариант с меньшей интенсивностью заражения.
#
# Такой набор позволяет визуально сравнить, как параметры `β` и `γ`
# влияют на скорость перераспределения популяции между состояниями
# `S`, `I` и `R`.

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

# ## Сводная таблица
#
# Для каждого сценария дополнительно сохраняется краткая сводка:
#
# - имя сценария;
# - значения параметров `β` и `γ`;
# - максимальное число инфицированных;
# - конечные значения `S`, `I`, `R`;
# - имя созданного GIF-файла.

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

# ## Основной цикл
#
# Для каждого набора параметров:
#
# 1. строится сеть Петри;
# 2. выполняется детерминированная симуляция;
# 3. создаётся GIF-анимация;
# 4. сохраняется краткая информация о результате.

for params in param_sets
    println("="^60)
    println("Сценарий: ", params.title)
    println("β = $(params.β), γ = $(params.γ), tmax = $(params.tmax)")

    # ### Построение сети Петри

    net, u0, states = build_sir_network(params.β, params.γ)

    # ### Детерминированная симуляция
    #
    # Для анимации используется детерминированный вариант модели,
    # чтобы получить плавную и наглядную динамику.

    df = simulate_deterministic(
        net,
        u0,
        (0.0, params.tmax),
        saveat = 0.2,
        rates = [params.β, params.γ],
    )

    # ### Построение GIF-анимации
    #
    # Каждый кадр показывает текущее распределение популяции между
    # состояниями `S`, `I` и `R`.

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

    # ### Сохранение сводной информации

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

# ## Сохранение сводной таблицы
#
# Таблица сохраняется прямо в каталог `data/`.

summary_file = datadir("sir_animation_params_summary.csv")
CSV.write(summary_file, summary)

println("="^60)
println("Параметризованное построение анимаций завершено.")
println("Сводная таблица сохранена в: ", summary_file)

# ## Итог
#
# После выполнения скрипта создаются три GIF-файла:
#
# - `plots/sir_animation_baseline.gif`;
# - `plots/sir_animation_fast_recovery.gif`;
# - `plots/sir_animation_lower_infection.gif`.
#
# Дополнительно создаётся таблица:
#
# - `data/sir_animation_params_summary.csv`.
#
# Эти результаты позволяют визуально сравнить, как изменение параметров
# заражения и выздоровления влияет на ход эпидемического процесса.
