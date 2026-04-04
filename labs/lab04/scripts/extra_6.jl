# # Дополнительное задание 6
# ## Оптимизация параметров модели SIR
#
# В данном эксперименте решается задача оптимизации параметров модели.
# Требуется подобрать такие значения параметров, при которых:
#
# - общее число умерших минимально;
# - пик заболеваемости не превышает 30% от общей численности популяции.
#
# В качестве настраиваемых параметров рассматриваются:
#
# - коэффициент заражения `β_und`;
# - время выявления инфекции `detection_time`;
# - вероятность смерти `death_rate`.
#
# Для ускорения вычислений используется облегчённая версия модели
# с уменьшенным числом агентов, числом шагов и количеством повторов.

using DrWatson
@quickactivate "project"

using BlackBoxOptim, Random, Statistics
using Agents
using JLD2
using DataFrames
using CSV
using Plots

include(srcdir("sir_model.jl"))

# ## Целевая функция
#
# Функция принимает вектор параметров `x`, где:
#
# - `x[1]` — коэффициент заражения `β_und`;
# - `x[2]` — время выявления инфекции;
# - `x[3]` — вероятность смерти.
#
# Для каждого набора параметров выполняется несколько прогонов модели.
# Основной целевой величиной является доля умерших.
#
# Если при этом пик заболеваемости превышает 30% популяции,
# к целевой функции добавляется штраф.

function cost_with_constraint(x)
    infected_frac(model) =
        count(a.status == :I for a in allagents(model)) / nagents(model)

    total_population = 1500
    dead_frac(model) = (total_population - nagents(model)) / total_population

    peak_vals = Float64[]
    dead_vals = Float64[]

    for rep in 1:2
        model = initialize_sir(;
            Ns = [500, 500, 500],
            β_und = fill(x[1], 3),
            β_det = fill(x[1] / 10, 3),
            infection_period = 10,
            detection_time = round(Int, x[2]),
            death_rate = x[3],
            reinfection_probability = 0.1,
            Is = [0, 0, 1],
            seed = 42 + rep,
            n_steps = 50,
        )

        peak_infected = 0.0

        for step in 1:50
            Agents.step!(model, 1)
            frac = infected_frac(model)
            if frac > peak_infected
                peak_infected = frac
            end
        end

        push!(peak_vals, peak_infected)
        push!(dead_vals, dead_frac(model))
    end

    mean_peak = mean(peak_vals)
    mean_dead = mean(dead_vals)

    penalty = 0.0
    if mean_peak > 0.30
        penalty = 10.0 * (mean_peak - 0.30)
    end

    return mean_dead + penalty
end

function main()

# ## Запуск оптимизации
#
# Используется алгоритм случайного поиска, который хорошо подходит
# для быстрой демонстрационной оптимизации и работает устойчиво.

    result = bboptimize(
        cost_with_constraint;
        Method = :random_search,
        SearchRange = [
            (0.1, 1.0),
            (3.0, 14.0),
            (0.01, 0.1),
        ],
        NumDimensions = 3,
        MaxTime = 20,
        TraceMode = :silent,
    )

# ## Извлечение найденных параметров
#
# После завершения оптимизации извлекаются найденные параметры
# и значение целевой функции.

    best = best_candidate(result)
    fitness = best_fitness(result)

    println("Оптимальные параметры:")
    println("β_und = $(best[1])")
    println("Время выявления = $(round(Int, best[2])) дней")
    println("Смертность = $(best[3])")
    println("Значение целевой функции = $(fitness)")

# ## Проверочный прогон
#
# Для найденных параметров выполним отдельный прогон модели,
# чтобы оценить фактический пик заболеваемости и долю умерших.

    model_check = initialize_sir(;
        Ns = [500, 500, 500],
        β_und = fill(best[1], 3),
        β_det = fill(best[1] / 10, 3),
        infection_period = 10,
        detection_time = round(Int, best[2]),
        death_rate = best[3],
        reinfection_probability = 0.1,
        Is = [0, 0, 1],
        seed = 123,
        n_steps = 50,
    )

    times = Int[]
    infected_vals = Float64[]
    dead_vals = Float64[]

    total_population = 1500
    peak_check = 0.0

    for step in 1:50
        Agents.step!(model_check, 1)

        current_infected = infected_count(model_check) / total_population
        current_dead = (total_population - total_count(model_check)) / total_population

        push!(times, step)
        push!(infected_vals, current_infected)
        push!(dead_vals, current_dead)

        if current_infected > peak_check
            peak_check = current_infected
        end
    end

    check_df = DataFrame(
        time = times,
        infected_fraction = infected_vals,
        dead_fraction = dead_vals,
    )

    println("Проверочный пик заболеваемости = $(round(peak_check, digits=3))")
    println("Порог 30% соблюдён: $(peak_check <= 0.30)")

# ## Построение графика проверочного прогона
#
# На графике отображаются:
#
# - доля инфицированных;
# - доля умерших;
# - горизонтальная линия ограничения 30%.

    p = plot(
        check_df.time,
        check_df.infected_fraction,
        label = "Доля инфицированных",
        xlabel = "Дни",
        ylabel = "Доля",
        title = "Проверка оптимального решения",
    )

    plot!(p, check_df.time, check_df.dead_fraction, label = "Доля умерших")
    hline!(p, [0.30], label = "Ограничение 30%")

    savefig(p, plotsdir("extra_6_optimization_check.png"))

# ## Сохранение результатов
#
# Сохраним найденные параметры, значение целевой функции
# и результаты проверочного прогона.

    CSV.write(datadir("extra_6_check.csv"), check_df)

    save(
        datadir("extra_6_optimization_result.jld2"),
        Dict(
            "best" => best,
            "fitness" => fitness,
            "peak_check" => peak_check,
            "check_df" => check_df,
        ),
    )

end

main()

# ## Вывод
#
# В результате оптимизации были найдены такие значения параметров модели,
# при которых минимизируется доля умерших с учётом ограничения на пик
# заболеваемости. Проверочный прогон позволяет убедиться, что найденное
# решение удовлетворяет условию по уровню эпидемического пика.
