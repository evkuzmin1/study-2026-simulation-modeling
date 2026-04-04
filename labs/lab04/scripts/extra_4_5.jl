# # Дополнительные задания 4–5
# ## Миграция и карантинные меры
#
# В данном файле объединены два дополнительных задания:
#
# - исследование влияния интенсивности миграции на распространение инфекции;
# - оценка эффективности карантинных мер.
#
# В первой части рассматривается, как изменение интенсивности перемещения
# агентов между городами влияет на скорость развития эпидемии.
# Во второй части вводится простая модель карантина: если доля инфицированных
# в городе превышает заданный порог, миграция из него прекращается.

using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Statistics
using JLD2

include(srcdir("sir_model.jl"))

# ## Функция построения матрицы миграции
#
# Матрица миграции создаётся по параметру интенсивности.
# Чем выше интенсивность, тем выше вероятность перехода агента
# из одного города в другой.

function create_migration_matrix(C, intensity)
    M = ones(C, C) .* intensity / (C - 1)
    for i in 1:C
        M[i, i] = 1 - intensity
    end
    return M
end

# ## Миграция без карантина
#
# Для заданного набора параметров вычисляются:
#
# - момент времени, когда достигается пик эпидемии;
# - величина этого пика.
#
# Здесь используется исходная модель миграции без ограничений.

function peak_time_without_quarantine(p)
    migration_rates = create_migration_matrix(p[:C], p[:migration_intensity])

    model = initialize_sir(;
        Ns = p[:Ns],
        β_und = p[:β_und],
        β_det = p[:β_det],
        infection_period = p[:infection_period],
        detection_time = p[:detection_time],
        death_rate = p[:death_rate],
        reinfection_probability = p[:reinfection_probability],
        Is = p[:Is],
        seed = p[:seed],
        migration_rates = migration_rates,
    )

    infected_frac(model) =
        count(a.status == :I for a in allagents(model)) / nagents(model)

    peak = 0.0
    peak_step = 0

    for step in 1:p[:n_steps]
        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing
            end
            if agent !== nothing
                sir_agent_step!(agent, model)
            end
        end

        frac = infected_frac(model)
        if frac > peak
            peak = frac
            peak_step = step
        end
    end

    return (peak_time = peak_step, peak_value = peak)
end

# ## Миграция с карантином
#
# В этом варианте используется простая карантинная мера:
# если доля инфицированных в городе превышает заданный порог,
# миграция из этого города обнуляется.

function peak_time_with_quarantine(p)
    migration_rates = create_migration_matrix(p[:C], p[:migration_intensity])

    model = initialize_sir(;
        Ns = p[:Ns],
        β_und = p[:β_und],
        β_det = p[:β_det],
        infection_period = p[:infection_period],
        detection_time = p[:detection_time],
        death_rate = p[:death_rate],
        reinfection_probability = p[:reinfection_probability],
        Is = p[:Is],
        seed = p[:seed],
        migration_rates = copy(migration_rates),
    )

    infected_frac(model) =
        count(a.status == :I for a in allagents(model)) / nagents(model)

    peak = 0.0
    peak_step = 0

    quarantine_threshold = p[:quarantine_threshold]
    quarantined_cities = falses(p[:C])

    for step in 1:p[:n_steps]
        for city in 1:p[:C]
            city_population = count(a.pos == city for a in allagents(model))
            city_infected = count(a.status == :I && a.pos == city for a in allagents(model))

            if city_population > 0
                city_frac = city_infected / city_population
                if city_frac > quarantine_threshold && !quarantined_cities[city]
                    model.migration_rates[city, :] .= 0.0
                    model.migration_rates[city, city] = 1.0
                    quarantined_cities[city] = true
                end
            end
        end

        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing
            end
            if agent !== nothing
                sir_agent_step!(agent, model)
            end
        end

        frac = infected_frac(model)
        if frac > peak
            peak = frac
            peak_step = step
        end
    end

    return (peak_time = peak_step, peak_value = peak)
end

function main()

# ## Формирование набора параметров
#
# Рассматриваются значения интенсивности миграции от 0.0 до 0.5
# с шагом 0.1. Для каждого значения выполняются три прогона модели
# с разными значениями генератора случайных чисел.

    migration_intensities = 0.0:0.1:0.5
    seeds = [42, 43, 44]

    params_list = []

    for mig in migration_intensities
        for s in seeds
            push!(
                params_list,
                Dict(
                    :migration_intensity => mig,
                    :C => 3,
                    :Ns => [1000, 1000, 1000],
                    :β_und => [0.5, 0.5, 0.5],
                    :β_det => [0.05, 0.05, 0.05],
                    :infection_period => 14,
                    :detection_time => 7,
                    :death_rate => 0.02,
                    :reinfection_probability => 0.1,
                    :Is => [1, 0, 0],
                    :seed => s,
                    :n_steps => 150,
                    :quarantine_threshold => 0.1,
                ),
            )
        end
    end

# ## Запуск экспериментов
#
# Для каждого набора параметров выполняются два расчёта:
#
# - без карантина;
# - с карантином.
#
# Затем результаты сохраняются в общую таблицу.

    results = DataFrame(
        migration_intensity = Float64[],
        seed = Int[],
        mode = String[],
        peak_time = Float64[],
        peak_value = Float64[],
    )

    for params in params_list
        res_no_q = peak_time_without_quarantine(params)
        push!(results, (
            params[:migration_intensity],
            params[:seed],
            "Без карантина",
            res_no_q.peak_time,
            res_no_q.peak_value,
        ))

        res_q = peak_time_with_quarantine(params)
        push!(results, (
            params[:migration_intensity],
            params[:seed],
            "С карантином",
            res_q.peak_time,
            res_q.peak_value,
        ))

        println("Завершён эксперимент: migration = $(params[:migration_intensity]), seed = $(params[:seed])")
    end

# ## Сохранение результатов
#
# Полная таблица результатов сохраняется в CSV-файл.

    CSV.write(datadir("extra_4_5_results.csv"), results)

# ## Усреднение результатов
#
# Для каждого значения интенсивности миграции и для каждого режима
# (с карантином и без карантина) вычисляются средние значения:
#
# - времени до пика;
# - величины пика.

    grouped = combine(
        groupby(results, [:migration_intensity, :mode]),
        :peak_time => mean => :mean_peak_time,
        :peak_value => mean => :mean_peak_value,
    )

# ## Построение графика времени до пика
#
# На первом графике сравнивается время достижения пика эпидемии
# при наличии и отсутствии карантина.

    p_time = plot(
        xlabel = "Интенсивность миграции",
        ylabel = "Среднее время до пика",
        title = "Миграция и карантин: время до пика",
    )

    for mode in unique(grouped.mode)
        subdf = grouped[grouped.mode .== mode, :]
        plot!(p_time, subdf.migration_intensity, subdf.mean_peak_time, label = mode, marker = :circle)
    end
    savefig(p_time, plotsdir("extra_4_5_peak_time.png"))

# ## Построение графика величины пика
#
# На втором графике сравнивается средняя величина пика
# для режимов с карантином и без карантина.

    p_peak = plot(
        xlabel = "Интенсивность миграции",
        ylabel = "Средняя пиковая доля инфицированных",
        title = "Миграция и карантин: величина пика",
    )

    for mode in unique(grouped.mode)
        subdf = grouped[grouped.mode .== mode, :]
        plot!(p_peak, subdf.migration_intensity, subdf.mean_peak_value, label = mode, marker = :square)
    end
    savefig(p_peak, plotsdir("extra_4_5_peak_value.png"))

# ## Сохранение итоговых данных
#
# Для удобства дальнейшего использования сохраним результаты и
# усреднённую таблицу в формате JLD2.

    save(datadir("extra_4_5_results.jld2"), Dict(
        "results" => results,
        "grouped" => grouped,
    ))
end

main()

# ## Вывод
#
# В результате выполнения дополнительных заданий 4–5 было исследовано
# влияние интенсивности миграции на скорость распространения инфекции,
# а также оценена эффективность карантинных мер.
#
# Сравнение режимов с карантином и без карантина позволяет определить,
# насколько ограничение миграции при росте заболеваемости помогает
# замедлить развитие эпидемии и снизить пиковую нагрузку.
