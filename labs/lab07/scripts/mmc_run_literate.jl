# # Лабораторная работа №7
# ## Дискретно-событийное моделирование: модель M/M/c
#
# В данном скрипте выполняется базовый запуск модели массового обслуживания
# M/M/c в дискретно-событийном подходе.
#
# Модель M/M/c описывает систему, в которую поступают заявки. Заявки обслуживаются
# несколькими параллельными каналами. Если все каналы заняты, заявка ожидает
# в очереди.
#
# В обозначении M/M/c:
#
# - первая `M` означает пуассоновский входящий поток заявок;
# - вторая `M` означает экспоненциальное распределение времени обслуживания;
# - `c` означает число параллельных каналов обслуживания.
#
# В этой версии используется source-модуль `MMCModel.jl`, в котором уже реализована
# вся основная логика модели: параметры, процессы, запуск симуляции, сбор событий
# и расчёт метрик.

using DrWatson
@quickactivate "project"

# Подключаем исходный модуль модели M/M/c.
# Он находится в каталоге `src/` проекта.

include(srcdir("MMCModel.jl"))
using .MMCModel

using DataFrames
using CSV
using Plots

# ## Задание параметров модели
#
# Зададим параметры базового эксперимента.
#
# В данном запуске моделируется система с двумя каналами обслуживания.
# Входящий поток имеет интенсивность `lambda = 0.9`, а интенсивность обслуживания
# одного канала равна `mu = 0.5`.
#
# Загрузка системы вычисляется по формуле:
#
# $$
# \rho = \frac{\lambda}{c \mu}.
# $$
#
# Для выбранных параметров:
#
# $$
# \rho = \frac{0.9}{2 \cdot 0.5} = 0.9.
# $$
#
# Значение меньше единицы, поэтому стационарный режим теоретически существует,
# однако система работает при высокой загрузке.

params = MMCParameters(
    num_customers = 200,
    num_servers = 2,
    lambda = 0.9,
    mu = 0.5,
    seed = 123,
)

# ## Запуск симуляции
#
# Запустим дискретно-событийную симуляцию M/M/c.
#
# Внутри функции `run_mmc_simulation` происходит:
#
# - генерация моментов поступления заявок;
# - запрос свободного канала обслуживания;
# - ожидание в очереди, если все каналы заняты;
# - обслуживание заявки;
# - фиксация событий прибытия, начала обслуживания и завершения обслуживания.

result = run_mmc_simulation(params)

# Выведем краткую сводку по результатам симуляции.

print_mmc_summary(result)

# ## Аналитические характеристики
#
# Для модели M/M/c можно также вычислить аналитические характеристики
# стационарного режима.
#
# Эти значения далее используются для сравнения с результатами имитационного
# моделирования.

analytics = mmc_analytics(params)

println()
println("Analytical M/M/c characteristics:")
println(analytics)

# ## Сохранение результатов
#
# Сохраним таблицы в каталог `data/`.
#
# В результате формируются:
#
# - `mmc_events.csv` — журнал событий модели;
# - `mmc_customers.csv` — таблица заявок;
# - `mmc_metrics.csv` — сводные метрики симуляции;
# - `mmc_analytics.csv` — аналитические характеристики;
# - `mmc_summary.csv` — таблица сравнения симуляции и аналитики.

CSV.write(datadir("mmc_events.csv"), result.events)
CSV.write(datadir("mmc_customers.csv"), result.customers)
CSV.write(datadir("mmc_metrics.csv"), result.metrics)
CSV.write(datadir("mmc_analytics.csv"), analytics)

# ## Сравнительная таблица
#
# Сформируем небольшую сравнительную таблицу по трём ключевым метрикам:
#
# - среднее время ожидания;
# - среднее время пребывания заявки в системе;
# - загрузка каналов обслуживания.

summary = DataFrame(
    metric = [
        "average waiting time",
        "average system time",
        "utilization",
    ],
    simulation = [
        result.metrics.avg_waiting_time[1],
        result.metrics.avg_system_time[1],
        result.metrics.utilization[1],
    ],
    analytical = [
        analytics.Wq[1],
        analytics.W[1],
        analytics.rho[1],
    ],
)

CSV.write(datadir("mmc_summary.csv"), summary)

# ## График длины очереди
#
# Первый график показывает изменение длины очереди во времени.
#
# Так как модель является дискретно-событийной, длина очереди меняется скачками:
# при поступлении заявки очередь может увеличиться, а при начале обслуживания —
# уменьшиться.

p_queue = plot(
    result.events.time,
    result.events.queue_length,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Queue length",
    title = "M/M/c queue length",
    label = "Queue",
    linewidth = 2,
)

savefig(p_queue, plotsdir("mmc_queue_length.png"))

# ## График занятости серверов
#
# Следующий график показывает число занятых каналов обслуживания во времени.
#
# Поскольку в модели используется два канала обслуживания, значение на графике
# может принимать значения от 0 до 2.

p_busy = plot(
    result.events.time,
    result.events.busy_servers,
    seriestype = :steppost,
    xlabel = "Time",
    ylabel = "Busy servers",
    title = "M/M/c busy servers",
    label = "Busy servers",
    linewidth = 2,
)

savefig(p_busy, plotsdir("mmc_busy_servers.png"))

# ## График времени ожидания
#
# Построим график времени ожидания каждой заявки.
#
# Время ожидания равно разности между моментом начала обслуживания и моментом
# прибытия заявки в систему.

p_wait = plot(
    result.customers.customer_id,
    result.customers.waiting_time,
    xlabel = "Customer ID",
    ylabel = "Waiting time",
    title = "M/M/c waiting time by customer",
    label = "Waiting time",
    marker = :circle,
    linewidth = 2,
)

savefig(p_wait, plotsdir("mmc_waiting_time.png"))

# ## График времени пребывания в системе
#
# Время пребывания в системе включает время ожидания и время обслуживания.
#
# Поэтому этот показатель обычно больше или равен времени ожидания.

p_system = plot(
    result.customers.customer_id,
    result.customers.system_time,
    xlabel = "Customer ID",
    ylabel = "System time",
    title = "M/M/c system time by customer",
    label = "System time",
    marker = :circle,
    linewidth = 2,
)

savefig(p_system, plotsdir("mmc_system_time.png"))

# ## Сравнение симуляции и аналитики
#
# Последний график сравнивает имитационные и аналитические значения.
#
# Аналитические значения соответствуют стационарному режиму M/M/c, а симуляция
# выполняется для конечного числа заявок. Поэтому результаты могут отличаться,
# особенно при высокой загрузке системы.

p_compare = bar(
    summary.metric,
    [summary.simulation summary.analytical],
    label = ["Simulation" "Analytical"],
    xlabel = "Metric",
    ylabel = "Value",
    title = "M/M/c simulation and analytical comparison",
    xrotation = 20,
)

savefig(p_compare, plotsdir("mmc_simulation_vs_analytics.png"))

# ## Итог
#
# В результате работы скрипта были получены таблицы с событиями и заявками,
# рассчитаны основные метрики модели M/M/c и построены графики:
#
# - длина очереди во времени;
# - число занятых каналов обслуживания;
# - время ожидания заявок;
# - время пребывания заявок в системе;
# - сравнение имитационных и аналитических характеристик.

println()
println("M/M/c simulation completed.")
println("Saved data:")
println("  data/mmc_events.csv")
println("  data/mmc_customers.csv")
println("  data/mmc_metrics.csv")
println("  data/mmc_analytics.csv")
println("  data/mmc_summary.csv")
println("Saved plots:")
println("  plots/mmc_queue_length.png")
println("  plots/mmc_busy_servers.png")
println("  plots/mmc_waiting_time.png")
println("  plots/mmc_system_time.png")
println("  plots/mmc_simulation_vs_analytics.png")
