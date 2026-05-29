# # Лабораторная работа №8
#
# ## Аналитический скрипт для DES SIR-модели
#
# В данном скрипте выполняется расширенный анализ дискретно-событийной
# SIR-модели.
#
# Здесь рассматриваются:
#
# - сравнение DES-модели с детерминированной SIR-моделью на ОДУ;
# - сценарий вакцинации;
# - вариант с фиксированной длительностью болезни;
# - сравнение пиков инфекции;
# - сравнение итогового размера эпидемии;
# - оценка производительности при разных размерах популяции.
#
# Базовая модель уже была реализована в `src/sir_model.jl`,
# поэтому здесь мы подключаем готовый source-модуль и используем его функции.

using DrWatson
@quickactivate "project"

include(srcdir("sir_model.jl"))
using .SIRModel

using CSV
using DataFrames
using Plots
using DifferentialEquations
using Random
using Distributions
using Literate

# ## Базовые параметры
#
# Зададим параметры, которые будут использоваться для сравнения разных
# вариантов модели. Эти параметры совпадают с базовым запуском SIR DES.

params = SIRParameters(
    990,     # начальное число восприимчивых
    10,      # начальное число инфицированных
    0,       # начальное число выздоровевших
    0.05,    # вероятность передачи инфекции
    10.0,    # среднее число контактов
    0.25,    # интенсивность выздоровления
    100.0,   # максимальное время моделирования
    123,     # seed
)

# ## Базовый DES-запуск
#
# Сначала выполним базовый запуск дискретно-событийной SIR-модели.
# Его результаты будут использоваться как основной сценарий для сравнения.

des_result = simulate_sir_des(params)
df_des = result_dataframe(des_result)
df_des_summary = summary_dataframe(des_result)

# ## Детерминированная SIR-модель
#
# Для сравнения реализуем классическую SIR-модель в виде системы
# дифференциальных уравнений.
#
# В отличие от DES-подхода, здесь состояние системы меняется непрерывно,
# а результат представляет собой гладкую траекторию.

function sir_ode!(du, u, p, t)
    beta, c, gamma, N = p

    S = u[1]
    I = u[2]
    R = u[3]

    infection = beta * c * S * I / N
    recovery = gamma * I

    du[1] = -infection
    du[2] = infection - recovery
    du[3] = recovery

    return nothing
end

N = params.S0 + params.I0 + params.R0
u0 = [params.S0, params.I0, params.R0]
p = [params.beta, params.c, params.gamma, N]
tspan = (0.0, params.tmax)

ode_problem = ODEProblem(sir_ode!, u0, tspan, p)
ode_solution = solve(ode_problem, Tsit5(); saveat = 0.5)

ode_values = Array(ode_solution)

df_ode = DataFrame(
    t = Float64.(ode_solution.t),
    S = ode_values[1, :],
    I = ode_values[2, :],
    R = ode_values[3, :],
)

ode_peak_I, ode_peak_index = findmax(df_ode.I)
ode_peak_time = df_ode.t[ode_peak_index]

df_ode_summary = DataFrame(
    model = ["ODE"],
    peak_I = [ode_peak_I],
    peak_time = [ode_peak_time],
    final_S = [df_ode.S[end]],
    final_I = [df_ode.I[end]],
    final_R = [df_ode.R[end]],
    final_size = [df_ode.R[end] - params.R0],
)

# ## Сценарий вакцинации
#
# Далее рассмотрим дополнительный сценарий вакцинации.
#
# В заданный момент времени часть восприимчивых агентов переводится
# в состояние `R`. Это означает, что они больше не участвуют в процессе
# заражения.

vaccination_result = simulate_sir_des_vaccination(
    params;
    vaccination_time = 10.0,
    vaccination_fraction = 0.25,
)

df_vaccination = result_dataframe(vaccination_result)
df_vaccination_summary = summary_dataframe(vaccination_result)

# ## Модель с фиксированной длительностью болезни
#
# Следующее дополнительное задание связано с заменой случайного времени
# выздоровления на фиксированную длительность болезни.
#
# В базовой DES-модели время выздоровления фактически является случайным,
# а здесь каждый инфицированный остаётся в состоянии `I` ровно
# `1 / gamma` единиц времени.

function simulate_sir_des_fixed_recovery(
    params::SIRParameters;
    illness_duration::Float64 = 1.0 / params.gamma,
)
    rng = MersenneTwister(params.seed)

    S = params.S0
    I = params.I0
    R = params.R0

    N = S + I + R
    t = 0.0

    time = Float64[t]
    S_values = Int[S]
    I_values = Int[I]
    R_values = Int[R]

    events = DataFrame(
        t = Float64[],
        event = Symbol[],
        S = Int[],
        I = Int[],
        R = Int[],
    )

    # Для начальных инфицированных заранее задаётся момент выздоровления.
    recovery_times = fill(illness_duration, I)

    while t < params.tmax
        if I == 0 && isempty(recovery_times)
            break
        end

        infection_rate = params.beta * params.c * S * I / N

        if infection_rate > 0.0 && S > 0
            next_infection_t = t + rand(rng, Exponential(1.0 / infection_rate))
        else
            next_infection_t = Inf
        end

        if !isempty(recovery_times)
            next_recovery_t, recovery_index = findmin(recovery_times)
        else
            next_recovery_t = Inf
            recovery_index = 0
        end

        next_t = min(next_infection_t, next_recovery_t)

        if next_t == Inf || next_t > params.tmax
            break
        end

        t = next_t

        if next_recovery_t <= next_infection_t
            I -= 1
            R += 1
            deleteat!(recovery_times, recovery_index)

            push!(
                events,
                (
                    t = t,
                    event = :fixed_recovery,
                    S = S,
                    I = I,
                    R = R,
                ),
            )
        else
            S -= 1
            I += 1
            push!(recovery_times, t + illness_duration)

            push!(
                events,
                (
                    t = t,
                    event = :infection,
                    S = S,
                    I = I,
                    R = R,
                ),
            )
        end

        push!(time, t)
        push!(S_values, S)
        push!(I_values, I)
        push!(R_values, R)
    end

    if time[end] < params.tmax
        push!(time, params.tmax)
        push!(S_values, S)
        push!(I_values, I)
        push!(R_values, R)
    end

    df_result = DataFrame(
        t = time,
        S = S_values,
        I = I_values,
        R = R_values,
    )

    peak_I, peak_index = findmax(df_result.I)
    peak_time = df_result.t[peak_index]

    df_summary = DataFrame(
        model = ["DES fixed recovery"],
        peak_I = [Float64(peak_I)],
        peak_time = [Float64(peak_time)],
        final_S = [Float64(df_result.S[end])],
        final_I = [Float64(df_result.I[end])],
        final_R = [Float64(df_result.R[end])],
        final_size = [Float64(df_result.R[end] - params.R0)],
        events_count = [nrow(events)],
        illness_duration = [illness_duration],
    )

    return df_result, events, df_summary
end

df_fixed, df_fixed_events, df_fixed_summary = simulate_sir_des_fixed_recovery(
    params;
    illness_duration = 1.0 / params.gamma,
)

# ## Общая таблица сравнения
#
# Соберём в одну таблицу основные показатели для всех вариантов:
#
# - базовая DES-модель;
# - детерминированная ODE-модель;
# - DES-модель с вакцинацией;
# - DES-модель с фиксированной длительностью болезни.

df_des_summary.model .= "DES base"
df_vaccination_summary.model .= "DES vaccination"

df_comparison = DataFrame(
    model = String[],
    peak_I = Float64[],
    peak_time = Float64[],
    final_S = Float64[],
    final_I = Float64[],
    final_R = Float64[],
    final_size = Float64[],
)

push!(
    df_comparison,
    (
        model = "DES base",
        peak_I = Float64(df_des_summary.peak_I[1]),
        peak_time = Float64(df_des_summary.peak_time[1]),
        final_S = Float64(df_des_summary.final_S[1]),
        final_I = Float64(df_des_summary.final_I[1]),
        final_R = Float64(df_des_summary.final_R[1]),
        final_size = Float64(df_des_summary.final_size[1]),
    ),
)

push!(
    df_comparison,
    (
        model = "ODE",
        peak_I = Float64(df_ode_summary.peak_I[1]),
        peak_time = Float64(df_ode_summary.peak_time[1]),
        final_S = Float64(df_ode_summary.final_S[1]),
        final_I = Float64(df_ode_summary.final_I[1]),
        final_R = Float64(df_ode_summary.final_R[1]),
        final_size = Float64(df_ode_summary.final_size[1]),
    ),
)

push!(
    df_comparison,
    (
        model = "DES vaccination",
        peak_I = Float64(df_vaccination_summary.peak_I[1]),
        peak_time = Float64(df_vaccination_summary.peak_time[1]),
        final_S = Float64(df_vaccination_summary.final_S[1]),
        final_I = Float64(df_vaccination_summary.final_I[1]),
        final_R = Float64(df_vaccination_summary.final_R[1]),
        final_size = Float64(df_vaccination_summary.final_size[1]),
    ),
)

push!(
    df_comparison,
    (
        model = "DES fixed recovery",
        peak_I = Float64(df_fixed_summary.peak_I[1]),
        peak_time = Float64(df_fixed_summary.peak_time[1]),
        final_S = Float64(df_fixed_summary.final_S[1]),
        final_I = Float64(df_fixed_summary.final_I[1]),
        final_R = Float64(df_fixed_summary.final_R[1]),
        final_size = Float64(df_fixed_summary.final_size[1]),
    ),
)

# ## Оценка производительности
#
# Для оценки производительности выполним запуск DES-модели при разных
# размерах популяции. Для каждого размера измеряется время выполнения.

population_sizes = [500, 1000, 2000, 5000]

df_performance = DataFrame(
    population_size = Int[],
    elapsed_time = Float64[],
    peak_I = Int[],
    final_size = Int[],
    events_count = Int[],
)

for population_size in population_sizes
    test_params = SIRParameters(
        population_size - 10,
        10,
        0,
        params.beta,
        params.c,
        params.gamma,
        params.tmax,
        5000 + population_size,
    )

    test_result = nothing

    elapsed_time = @elapsed begin
        test_result = simulate_sir_des(test_params)
    end

    test_summary = summary_dataframe(test_result)

    push!(
        df_performance,
        (
            population_size = population_size,
            elapsed_time = elapsed_time,
            peak_I = test_summary.peak_I[1],
            final_size = test_summary.final_size[1],
            events_count = test_summary.events_count[1],
        ),
    )
end

# ## Сохранение таблиц
#
# Сохраним все полученные таблицы в каталог `data/`.

CSV.write(datadir("sir_des_analysis_literate_des.csv"), df_des)
CSV.write(datadir("sir_des_analysis_literate_ode.csv"), df_ode)
CSV.write(datadir("sir_des_analysis_literate_vaccination.csv"), df_vaccination)
CSV.write(datadir("sir_des_analysis_literate_fixed_recovery.csv"), df_fixed)
CSV.write(datadir("sir_des_analysis_literate_fixed_recovery_events.csv"), df_fixed_events)
CSV.write(datadir("sir_des_analysis_literate_comparison.csv"), df_comparison)
CSV.write(datadir("sir_des_analysis_literate_performance.csv"), df_performance)

println("SIR DES analysis comparison:")
println(df_comparison)

println()
println("SIR DES performance:")
println(df_performance)

# ## Сравнение DES и ODE
#
# Первый график сравнивает динамику инфицированных в дискретно-событийной
# и детерминированной моделях.

p_compare_infected = plot(
    df_des.t,
    df_des.I,
    label = "DES infected",
    xlabel = "Time",
    ylabel = "Infected",
    title = "SIR: DES and ODE infected comparison",
    linewidth = 2,
)

plot!(
    p_compare_infected,
    df_ode.t,
    df_ode.I,
    label = "ODE infected",
    linewidth = 2,
)

savefig(p_compare_infected, plotsdir("sir_des_analysis_literate_des_vs_ode.png"))

# ## Сценарий вакцинации
#
# Второй график показывает, как вакцинация влияет на число инфицированных.
# Вакцинация снижает количество восприимчивых агентов, поэтому пик инфекции
# становится ниже.

p_vaccination = plot(
    df_des.t,
    df_des.I,
    label = "Base infected",
    xlabel = "Time",
    ylabel = "Infected",
    title = "SIR DES: base and vaccination scenarios",
    linewidth = 2,
)

plot!(
    p_vaccination,
    df_vaccination.t,
    df_vaccination.I,
    label = "Vaccination infected",
    linewidth = 2,
)

savefig(p_vaccination, plotsdir("sir_des_analysis_literate_vaccination.png"))

# ## Фиксированная длительность болезни
#
# Третий график сравнивает стохастическое выздоровление и фиксированную
# длительность болезни.

p_fixed = plot(
    df_des.t,
    df_des.I,
    label = "Stochastic recovery",
    xlabel = "Time",
    ylabel = "Infected",
    title = "SIR DES: stochastic and fixed recovery",
    linewidth = 2,
)

plot!(
    p_fixed,
    df_fixed.t,
    df_fixed.I,
    label = "Fixed recovery",
    linewidth = 2,
)

savefig(p_fixed, plotsdir("sir_des_analysis_literate_fixed_recovery.png"))

# ## Сравнение пиков инфекции
#
# На следующей диаграмме сравним максимальное количество инфицированных
# для всех вариантов модели.

x_positions = collect(1:nrow(df_comparison))

p_peak_comparison = bar(
    x_positions,
    df_comparison.peak_I,
    label = "Peak infected",
    xlabel = "Model",
    ylabel = "Peak infected",
    title = "SIR: infection peak comparison",
    xticks = (x_positions, df_comparison.model),
    xrotation = 25,
)

savefig(p_peak_comparison, plotsdir("sir_des_analysis_literate_peak_comparison.png"))

# ## Сравнение итогового размера эпидемии
#
# Итоговый размер эпидемии показывает, сколько агентов перешло в состояние
# `R` к концу моделирования.

p_final_size = bar(
    x_positions,
    df_comparison.final_size,
    label = "Final size",
    xlabel = "Model",
    ylabel = "Final epidemic size",
    title = "SIR: final epidemic size comparison",
    xticks = (x_positions, df_comparison.model),
    xrotation = 25,
)

savefig(p_final_size, plotsdir("sir_des_analysis_literate_final_size_comparison.png"))

# ## Производительность
#
# Последний график показывает зависимость времени выполнения модели
# от размера популяции.

p_performance = plot(
    df_performance.population_size,
    df_performance.elapsed_time,
    marker = :circle,
    label = "Elapsed time",
    xlabel = "Population size",
    ylabel = "Elapsed time, seconds",
    title = "SIR DES: performance by population size",
    linewidth = 2,
)

savefig(p_performance, plotsdir("sir_des_analysis_literate_performance.png"))

# ## Итог
#
# В результате выполнения аналитического скрипта были получены таблицы
# сравнения, графики разных сценариев и оценка производительности модели.

println()
println("SIR DES analysis literate completed.")
println("Saved data:")
println("  data/sir_des_analysis_literate_des.csv")
println("  data/sir_des_analysis_literate_ode.csv")
println("  data/sir_des_analysis_literate_vaccination.csv")
println("  data/sir_des_analysis_literate_fixed_recovery.csv")
println("  data/sir_des_analysis_literate_fixed_recovery_events.csv")
println("  data/sir_des_analysis_literate_comparison.csv")
println("  data/sir_des_analysis_literate_performance.csv")
println("Saved plots:")
println("  plots/sir_des_analysis_literate_des_vs_ode.png")
println("  plots/sir_des_analysis_literate_vaccination.png")
println("  plots/sir_des_analysis_literate_fixed_recovery.png")
println("  plots/sir_des_analysis_literate_peak_comparison.png")
println("  plots/sir_des_analysis_literate_final_size_comparison.png")
println("  plots/sir_des_analysis_literate_performance.png")

# ## Генерация файлов из literate-версии
#
# В конце создаются производные файлы:
#
# - чистый Julia-скрипт;
# - Jupyter Notebook;
# - Quarto-документ.

output_dir = scriptsdir("generated", "sir_des_analysis_literate")
mkpath(output_dir)

Literate.script(@__FILE__, output_dir)
Literate.notebook(@__FILE__, output_dir)
Literate.markdown(@__FILE__, output_dir; flavor = Literate.QuartoFlavor())

println()
println("Generated literate outputs:")
println("  scripts/generated/sir_des_analysis_literate/")
