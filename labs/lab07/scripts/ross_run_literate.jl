# # Лабораторная работа №7
# ## Дискретно-событийное моделирование: модель Росса
#
# В данном скрипте выполняется базовый запуск модели Росса.
#
# Модель Росса используется для анализа надёжности технической системы,
# состоящей из работающих машин, резервных машин и ремонтников.
#
# В системе постоянно должно работать заданное число машин. Если одна из
# работающих машин выходит из строя, она заменяется резервной машиной.
# Сломанная машина отправляется в ремонт. Если свободного ремонтника нет,
# машина становится в очередь на ремонт.
#
# Если отказ происходит в тот момент, когда резервных машин уже не осталось,
# система считается отказавшей.
#
# Вся основная логика модели вынесена в source-модуль `RossModel.jl`.
# В этом скрипте задаются параметры, запускается симуляция, сохраняются
# результаты и строятся графики.

using DrWatson
@quickactivate "project"

# Подключаем source-модуль модели Росса.
# В нём реализованы параметры модели, запуск симуляции, повторные прогоны,
# расчёт метрик и аналитическая оценка среднего времени до отказа.

include(srcdir("RossModel.jl"))
using .RossModel

using DataFrames
using CSV
using Plots

# ## Задание параметров модели
#
# Зададим параметры базового эксперимента.
#
# В данном запуске используются:
#
# - `num_operating = 5` — число машин, которые должны постоянно работать;
# - `num_spares = 3` — число резервных машин;
# - `num_repairers = 1` — число ремонтников;
# - `failure_rate = 0.1` — интенсивность отказа одной работающей машины;
# - `repair_rate = 0.5` — интенсивность ремонта одной машины;
# - `seed = 123` — зерно генератора случайных чисел;
# - `max_time = 1000.0` — максимальное время моделирования.
#
# Фиксация `seed` нужна для воспроизводимости результата.

params = RossParameters(
    num_operating = 5,
    num_spares = 3,
    num_repairers = 1,
    failure_rate = 0.1,
    repair_rate = 0.5,
    seed = 123,
    max_time = 1000.0,
)

# ## Запуск одной симуляции
#
# Запустим одну дискретно-событийную симуляцию модели Росса.
#
# Внутри функции `run_ross_simulation` последовательно обрабатываются события:
#
# - отказ работающей машины;
# - начало ремонта;
# - ожидание ремонта в очереди;
# - завершение ремонта;
# - возврат машины в резерв;
# - отказ всей системы при отсутствии резерва.
#
# Результатом работы функции является история состояний системы и таблица
# основных метрик.

result = run_ross_simulation(params)

# Выведем краткую сводку по базовому запуску.

print_ross_summary(result)

# ## Повторные прогоны модели
#
# Один запуск модели Росса зависит от случайных моментов отказов и ремонтов.
# Поэтому по одному запуску нельзя надёжно оценивать среднее время до отказа.
#
# Для более устойчивой оценки выполним серию независимых повторов модели.
# В данном случае используется `100` повторов.

replications = run_ross_replications(params; n_replications = 100)

println()
println("Ross model replications summary:")
println(replications.summary)

# ## Сохранение результатов
#
# Сохраним результаты моделирования в каталог `data/`.
#
# Формируются следующие файлы:
#
# - `ross_history.csv` — история одного базового запуска;
# - `ross_metrics.csv` — метрики одного базового запуска;
# - `ross_replications.csv` — результаты независимых повторов;
# - `ross_replications_summary.csv` — сводка по серии повторов.

CSV.write(datadir("ross_history.csv"), result.history)
CSV.write(datadir("ross_metrics.csv"), result.metrics)
CSV.write(datadir("ross_replications.csv"), replications.replications)
CSV.write(datadir("ross_replications_summary.csv"), replications.summary)

# ## Сравнение имитационного и аналитического MTTF
#
# Для модели рассчитывается среднее время до отказа.
#
# В имитационном подходе оно оценивается по серии повторов.
# В аналитическом подходе используется функция `ross_analytic_mttf`,
# реализованная в source-модуле.
#
# Создадим таблицу для сравнения этих двух значений.

comparison = DataFrame(
    metric = ["Simulation mean", "Analytical MTTF"],
    value = [
        replications.summary.mean_time_to_failure[1],
        replications.summary.analytic_mttf[1],
    ],
)

CSV.write(datadir("ross_mttf_comparison.csv"), comparison)

# ## График доступных резервных машин
#
# Первый график показывает, как во времени меняется количество доступных
# резервных машин.
#
# При отказе работающей машины резерв уменьшается, потому что одна резервная
# машина используется для замены. После завершения ремонта отремонтированная
# машина возвращается в резерв.

p_spares = plot(
    result.history.time,
    result.history.spares_available,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Available spares",
    title = "Ross model: available spare machines",
    label = "Spares",
    linewidth = 2,
)

savefig(p_spares, plotsdir("ross_spares_available.png"))

# ## График очереди на ремонт
#
# Второй график показывает длину очереди на ремонт.
#
# Если ремонтник свободен, сломанная машина сразу попадает в ремонт.
# Если ремонтник занят, машина становится в очередь.
#
# В базовом сценарии используется один ремонтник, поэтому при накоплении
# отказов очередь может возрастать.

p_queue = plot(
    result.history.time,
    result.history.repair_queue,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Repair queue length",
    title = "Ross model: repair queue",
    label = "Repair queue",
    linewidth = 2,
)

savefig(p_queue, plotsdir("ross_repair_queue.png"))

# ## График занятости ремонтников
#
# Третий график показывает число занятых ремонтников во времени.
#
# Поскольку в базовом варианте ремонтник один, график принимает значения
# `0` или `1`.
#
# Значение `1` означает, что ремонтник занят. Значение `0` означает, что
# в данный момент ремонтник свободен.

p_busy = plot(
    result.history.time,
    result.history.repairers_busy,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Busy repairers",
    title = "Ross model: busy repairers",
    label = "Busy repairers",
    linewidth = 2,
)

savefig(p_busy, plotsdir("ross_busy_repairers.png"))

# ## График времени до отказа
#
# Построим график времени до отказа по независимым повторам.
#
# Каждая точка соответствует одному прогону модели. Разброс значений возникает
# из-за случайного характера отказов и ремонтов.

p_ttf = plot(
    replications.replications.replication,
    replications.replications.time_to_failure,
    xlabel = "Replication",
    ylabel = "Time to failure",
    title = "Ross model: time to failure by replication",
    label = "Time to failure",
    marker = :circle,
    linewidth = 2,
)

savefig(p_ttf, plotsdir("ross_time_to_failure.png"))

# ## Сравнение среднего времени до отказа
#
# Последний график сравнивает среднее время до отказа по серии имитационных
# прогонов и аналитическую оценку MTTF.
#
# Небольшое различие между этими значениями нормально, так как имитационная
# оценка строится по конечному числу случайных повторов.

p_compare = bar(
    comparison.metric,
    comparison.value,
    xlabel = "Method",
    ylabel = "Mean time to failure",
    title = "Ross model: simulation and analytical MTTF",
    label = "MTTF",
    xrotation = 15,
)

savefig(p_compare, plotsdir("ross_mttf_comparison.png"))

# ## Итог
#
# В результате работы скрипта были получены:
#
# - история изменения состояния системы;
# - таблица метрик одного запуска;
# - результаты серии независимых повторов;
# - сравнение имитационного и аналитического среднего времени до отказа;
# - графики доступного резерва, очереди на ремонт, занятости ремонтников
#   и времени до отказа.
#
# Полученные результаты позволяют проанализировать надёжность системы,
# влияние резерва и загрузку ремонтного ресурса.

println()
println("Ross model simulation completed.")
println("Saved data:")
println("  data/ross_history.csv")
println("  data/ross_metrics.csv")
println("  data/ross_replications.csv")
println("  data/ross_replications_summary.csv")
println("  data/ross_mttf_comparison.csv")
println("Saved plots:")
println("  plots/ross_spares_available.png")
println("  plots/ross_repair_queue.png")
println("  plots/ross_busy_repairers.png")
println("  plots/ross_time_to_failure.png")
println("  plots/ross_mttf_comparison.png")
