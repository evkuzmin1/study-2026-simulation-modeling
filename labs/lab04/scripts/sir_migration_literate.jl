# # Лабораторная работа 4
# ## Исследование эффекта миграции в модели SIR
#
# В данном эксперименте исследуется влияние интенсивности миграции
# между городами на динамику эпидемического процесса.
#
# В отличие от предыдущих экспериментов, здесь изменяется не коэффициент
# заражения, а интенсивность перемещения агентов между тремя городами.
# Цель исследования состоит в том, чтобы определить, как миграция влияет:
#
# - на время достижения пика эпидемии;
# - на величину пика заболеваемости.
#
# Предполагается, что при увеличении миграции инфекция будет быстрее
# распространяться между городами, что приведёт к более раннему и,
# возможно, более высокому пику эпидемии.

using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Random
using Statistics

include(srcdir("sir_model.jl"))

# ## Функция создания матрицы миграции
#
# Для исследования вводится параметр интенсивности миграции.
# На его основе строится матрица миграции между городами.
#
# Если интенсивность миграции равна нулю, агенты остаются в своих городах.
# При увеличении параметра возрастает вероятность перемещения в другие города.

function create_migration_matrix(C, intensity)
M = ones(C, C) .* intensity / (C - 1)
for i in 1:C
M[i, i] = 1 - intensity
end
return M
end

# ## Функция измерения времени достижения пика
#
# Для каждого набора параметров выполняется моделирование, после чего
# определяются:
#
# - момент времени, когда доля инфицированных достигает максимума;
# - значение этого максимума.

function peak_time(p)
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

# ## Диапазон значений интенсивности миграции
#
# Рассматриваются значения интенсивности миграции от 0.0 до 0.5
# с шагом 0.1. Для каждого значения выполняются три прогона модели
# с различными значениями генератора случайных чисел.

migration_intensities = 0.0:0.1:0.5
seeds = [42, 43, 44]

# ## Формирование списка параметров
#
# Для каждого значения интенсивности миграции и каждого значения seed
# создаётся отдельный набор параметров.

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
),
)
end
end

# ## Запуск экспериментов
#
# Для каждого набора параметров выполняется отдельное моделирование,
# а результаты сохраняются в общий массив.

results = []

for params in params_list
data = peak_time(params)
push!(results, merge(params, Dict(pairs(data))))
println("Завершён эксперимент с migration_intensity = $(params[:migration_intensity]), seed = $(params[:seed])")
end

# ## Сохранение результатов
#
# Результаты всех прогонов сохраняются в CSV-файл для последующего анализа.

df = DataFrame(results)
CSV.write(datadir("migration_scan_all.csv"), df)

# ## Усреднение результатов
#
# Для каждого значения интенсивности миграции вычисляются средние значения:
#
# - времени достижения пика;
# - величины пика заболеваемости.

grouped = combine(
groupby(df, [:migration_intensity]),
:peak_time => mean => :mean_peak_time,
:peak_value => mean => :mean_peak_value,
)

# ## Визуализация результатов
#
# Построим график зависимости времени до пика и величины пика
# от интенсивности миграции.

plot(
grouped.migration_intensity,
grouped.mean_peak_time,
marker = :circle,
xlabel = "Интенсивность миграции",
ylabel = "Значение показателя",
label = "Время пика",
)

plot!(
grouped.migration_intensity,
grouped.mean_peak_value .* 3000,
marker = :square,
label = "Пиковая заболеваемость",
)

savefig(plotsdir("migration_effect.png"))

println("Результаты сохранены в data/migration_scan_all.csv и plots/migration_effect.png")

# ## Вывод
#
# В результате моделирования была исследована зависимость времени
# достижения пика эпидемии и величины пика заболеваемости от интенсивности
# миграции между городами.
#
# Увеличение интенсивности миграции приводит к более быстрому распространению
# инфекции между городами, что, как правило, сокращает время до достижения
# пика эпидемии и увеличивает величину этого пика.
