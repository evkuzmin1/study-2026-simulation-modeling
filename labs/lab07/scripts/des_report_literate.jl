# # Лабораторная работа №7
# ## Дискретно-событийное моделирование: итоговый отчётный скрипт
#
# В данном скрипте формируются итоговые таблицы и графики по результатам
# дискретно-событийного моделирования.
#
# В лабораторной работе были рассмотрены две модели:
#
# - модель массового обслуживания M/M/c;
# - модель Росса для анализа надёжности системы с резервом и ремонтом.
#
# В отличие от скриптов `mmc_run.jl` и `ross_run.jl`, данный файл не запускает
# модели заново. Он использует уже сохранённые CSV-файлы, которые были получены
# после выполнения базовых и параметризованных экспериментов.
#
# Основная задача этого скрипта:
#
# - загрузить результаты моделирования;
# - сформировать итоговые сводные таблицы;
# - построить финальные графики для отчёта;
# - сохранить результаты в каталоги `data/` и `plots/`.

using DrWatson
@quickactivate "project"

using DataFrames
using CSV
using Plots

# ## Загрузка результатов модели M/M/c
#
# Сначала загрузим результаты, полученные для модели M/M/c.
#
# Используются следующие файлы:
#
# - `mmc_metrics.csv` — метрики базовой симуляции;
# - `mmc_analytics.csv` — аналитические характеристики M/M/c;
# - `mmc_summary.csv` — сравнение симуляции и аналитики;
# - `mmc_params_compare.csv` — результаты параметризованного эксперимента.

mmc_metrics = CSV.read(datadir("mmc_metrics.csv"), DataFrame)
mmc_analytics = CSV.read(datadir("mmc_analytics.csv"), DataFrame)
mmc_summary = CSV.read(datadir("mmc_summary.csv"), DataFrame)
mmc_params_compare = CSV.read(datadir("mmc_params_compare.csv"), DataFrame)

# ## Загрузка результатов модели Росса
#
# Далее загрузим результаты для модели Росса.
#
# Используются следующие файлы:
#
# - `ross_metrics.csv` — метрики одного базового запуска;
# - `ross_replications_summary.csv` — сводка по серии повторов;
# - `ross_mttf_comparison.csv` — сравнение имитационного и аналитического MTTF;
# - `ross_params_summary.csv` — результаты параметризованного эксперимента;
# - `ross_params_mttf_compare.csv` — сравнение MTTF при разном числе ремонтников.

ross_metrics = CSV.read(datadir("ross_metrics.csv"), DataFrame)
ross_replications_summary = CSV.read(datadir("ross_replications_summary.csv"), DataFrame)
ross_mttf_comparison = CSV.read(datadir("ross_mttf_comparison.csv"), DataFrame)
ross_params_summary = CSV.read(datadir("ross_params_summary.csv"), DataFrame)
ross_params_mttf_compare = CSV.read(datadir("ross_params_mttf_compare.csv"), DataFrame)

# ## Итоговая сводка по модели M/M/c
#
# Сформируем таблицу с основными характеристиками базового запуска M/M/c.
#
# В таблицу включаются:
#
# - число заявок;
# - число серверов;
# - параметры `lambda` и `mu`;
# - имитационная и аналитическая загрузка;
# - среднее время ожидания;
# - среднее время пребывания заявки в системе;
# - максимальная длина очереди.

mmc_final_summary = DataFrame(
    model = ["M/M/c"],
    num_customers = [mmc_metrics.num_customers[1]],
    num_servers = [mmc_metrics.num_servers[1]],
    lambda = [mmc_metrics.lambda[1]],
    mu = [mmc_metrics.mu[1]],
    rho_simulation = [mmc_metrics.utilization[1]],
    rho_analytical = [mmc_analytics.rho[1]],
    avg_waiting_time_simulation = [mmc_metrics.avg_waiting_time[1]],
    avg_waiting_time_analytical = [mmc_analytics.Wq[1]],
    avg_system_time_simulation = [mmc_metrics.avg_system_time[1]],
    avg_system_time_analytical = [mmc_analytics.W[1]],
    max_queue_length = [mmc_metrics.max_queue_length[1]],
)

CSV.write(datadir("des_mmc_final_summary.csv"), mmc_final_summary)

# ## Итоговая сводка по модели Росса
#
# Теперь сформируем таблицу с основными характеристиками модели Росса.
#
# В таблицу включаются:
#
# - число работающих машин;
# - число резервных машин;
# - число ремонтников;
# - интенсивность отказов;
# - интенсивность ремонта;
# - время до отказа в одном запуске;
# - среднее время до отказа по серии повторов;
# - аналитическое значение MTTF;
# - средняя очередь на ремонт;
# - загрузка ремонтника.

ross_final_summary = DataFrame(
    model = ["Ross model"],
    num_operating = [ross_metrics.num_operating[1]],
    num_spares = [ross_metrics.num_spares[1]],
    num_repairers = [ross_metrics.num_repairers[1]],
    failure_rate = [ross_metrics.failure_rate[1]],
    repair_rate = [ross_metrics.repair_rate[1]],
    time_to_failure_single_run = [ross_metrics.time_to_failure[1]],
    mean_time_to_failure_simulation = [
        ross_replications_summary.mean_time_to_failure[1],
    ],
    mean_time_to_failure_analytical = [
        ross_replications_summary.analytic_mttf[1],
    ],
    avg_repair_queue = [ross_metrics.avg_repair_queue[1]],
    repairer_utilization = [ross_metrics.repairer_utilization[1]],
)

CSV.write(datadir("des_ross_final_summary.csv"), ross_final_summary)

# ## Общая обзорная таблица
#
# Создадим небольшую итоговую таблицу, которая кратко сравнивает две модели.
#
# Эта таблица нужна для финального раздела отчёта: она показывает, какой объект
# моделировался, какой параметр изменялся и какой общий вывод был получен.

des_overview = DataFrame(
    model = [
        "M/M/c",
        "Ross model",
    ],
    object = [
        "Queueing system with several service channels",
        "Reliability system with spare machines and repairers",
    ],
    main_variable = [
        "Number of servers",
        "Number of repairers",
    ],
    main_metric = [
        "Waiting time and queue length",
        "Mean time to failure and repair queue",
    ],
    conclusion = [
        "Increasing the number of servers reduces waiting time and queue length.",
        "Increasing the number of repairers increases mean time to failure and reduces repair queue.",
    ],
)

CSV.write(datadir("des_overview.csv"), des_overview)

# ## График 1. Сравнение симуляции и аналитики для M/M/c
#
# Первый график сравнивает имитационные и аналитические значения для базовой
# модели M/M/c.
#
# Для большей устойчивости используется числовая ось `x` и подписи через
# `xticks`. Это позволяет избежать ошибок backend `GR` при работе со строковыми
# подписями на оси X.

x_mmc = collect(1:nrow(mmc_summary))

p_mmc_compare = bar(
    x_mmc .- 0.15,
    mmc_summary.simulation,
    bar_width = 0.3,
    label = "Simulation",
    xlabel = "Metric",
    ylabel = "Value",
    title = "M/M/c: simulation and analytical comparison",
    xticks = (x_mmc, mmc_summary.metric),
    xrotation = 20,
)

bar!(
    p_mmc_compare,
    x_mmc .+ 0.15,
    mmc_summary.analytical,
    bar_width = 0.3,
    label = "Analytical",
)

savefig(p_mmc_compare, plotsdir("des_mmc_simulation_vs_analytics.png"))

# ## График 2. Влияние числа серверов на временные характеристики
#
# Следующий график показывает, как изменение числа серверов влияет на:
#
# - среднее время ожидания заявки;
# - среднее время пребывания заявки в системе.
#
# Ожидаемый результат: при увеличении числа серверов обе характеристики должны
# уменьшаться, так как система получает больше каналов обслуживания.

x_servers = collect(mmc_params_compare.num_servers)

p_mmc_time = plot(
    x_servers,
    mmc_params_compare.avg_waiting_time_mean,
    marker = :circle,
    xlabel = "Number of servers",
    ylabel = "Time",
    title = "M/M/c: effect of servers on time metrics",
    label = "Average waiting time",
    linewidth = 2,
)

plot!(
    p_mmc_time,
    x_servers,
    mmc_params_compare.avg_system_time_mean,
    marker = :circle,
    label = "Average system time",
    linewidth = 2,
)

savefig(p_mmc_time, plotsdir("des_mmc_time_by_servers.png"))

# ## График 3. Влияние числа серверов на очередь
#
# Этот график показывает зависимость средней максимальной длины очереди
# от числа серверов.
#
# При увеличении числа серверов очередь должна сокращаться, потому что заявки
# быстрее получают свободный канал обслуживания.

p_mmc_queue = plot(
    x_servers,
    mmc_params_compare.max_queue_length_mean,
    marker = :circle,
    xlabel = "Number of servers",
    ylabel = "Average max queue length",
    title = "M/M/c: effect of servers on queue length",
    label = "Max queue length",
    linewidth = 2,
)

savefig(p_mmc_queue, plotsdir("des_mmc_queue_by_servers.png"))

# ## График 4. Сравнение MTTF для модели Росса
#
# Для модели Росса сравним среднее время до отказа, полученное по серии
# имитационных прогонов, с аналитической оценкой MTTF.
#
# Если значения близки, это подтверждает корректность реализации модели.

x_ross = collect(1:nrow(ross_mttf_comparison))

p_ross_compare = bar(
    x_ross,
    ross_mttf_comparison.value,
    xlabel = "Method",
    ylabel = "Mean time to failure",
    title = "Ross model: simulation and analytical MTTF",
    label = "MTTF",
    xticks = (x_ross, ross_mttf_comparison.metric),
    xrotation = 15,
)

savefig(p_ross_compare, plotsdir("des_ross_mttf_comparison.png"))

# ## График 5. Влияние числа ремонтников на MTTF
#
# Теперь рассмотрим параметризованный эксперимент модели Росса.
#
# На графике показано, как число ремонтников влияет на среднее время до отказа.
# При увеличении числа ремонтников сломанные машины быстрее возвращаются в
# резерв, поэтому система в среднем должна работать дольше.

x_repairers_compare = collect(ross_params_mttf_compare.num_repairers)

p_ross_mttf = plot(
    x_repairers_compare,
    ross_params_mttf_compare.simulation_mttf,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Mean time to failure",
    title = "Ross model: effect of repairers on MTTF",
    label = "Simulation mean",
    linewidth = 2,
)

plot!(
    p_ross_mttf,
    x_repairers_compare,
    ross_params_mttf_compare.analytical_mttf,
    marker = :circle,
    label = "Analytical MTTF",
    linewidth = 2,
)

savefig(p_ross_mttf, plotsdir("des_ross_mttf_by_repairers.png"))

# ## График 6. Очередь на ремонт и загрузка ремонтников
#
# Последний график объединяет две характеристики модели Росса:
#
# - среднюю очередь на ремонт;
# - среднюю загрузку ремонтников.
#
# При увеличении числа ремонтников очередь должна уменьшаться. При этом средняя
# загрузка каждого ремонтника также снижается, так как ремонтная нагрузка
# распределяется между большим количеством ресурсов.

x_repairers = collect(ross_params_summary.num_repairers)

p_ross_queue = plot(
    x_repairers,
    ross_params_summary.mean_repair_queue,
    marker = :circle,
    xlabel = "Number of repairers",
    ylabel = "Value",
    title = "Ross model: repair queue and utilization",
    label = "Mean repair queue",
    linewidth = 2,
)

plot!(
    p_ross_queue,
    x_repairers,
    ross_params_summary.mean_repairer_utilization,
    marker = :circle,
    label = "Repairer utilization",
    linewidth = 2,
)

savefig(p_ross_queue, plotsdir("des_ross_queue_utilization.png"))

# ## Итог
#
# В результате работы итогового отчётного скрипта были сформированы:
#
# - сводная таблица по модели M/M/c;
# - сводная таблица по модели Росса;
# - общая обзорная таблица по двум моделям;
# - итоговые графики для отчёта.
#
# Полученные результаты подтверждают, что увеличение числа серверов в модели
# M/M/c снижает очередь и время ожидания, а увеличение числа ремонтников в модели
# Росса повышает среднее время до отказа и уменьшает очередь на ремонт.

println("Discrete-event simulation report completed.")

println()
println("Saved data:")
println("  data/des_mmc_final_summary.csv")
println("  data/des_ross_final_summary.csv")
println("  data/des_overview.csv")

println()
println("Saved plots:")
println("  plots/des_mmc_simulation_vs_analytics.png")
println("  plots/des_mmc_time_by_servers.png")
println("  plots/des_mmc_queue_by_servers.png")
println("  plots/des_ross_mttf_comparison.png")
println("  plots/des_ross_mttf_by_repairers.png")
println("  plots/des_ross_queue_utilization.png")
