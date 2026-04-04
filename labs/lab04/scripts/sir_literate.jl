# # Лабораторная работа 4
# ## Реализация модели SIR в агентном подходе
#
# В данной работе рассматривается реализация эпидемиологической модели SIR
# в агентном подходе. В отличие от непрерывной модели, основанной на
# дифференциальных уравнениях, здесь каждый человек задаётся отдельным агентом.
# Агент может находиться в одном из трёх состояний:
#
# - `S` — восприимчивый;
# - `I` — инфицированный;
# - `R` — выздоровевший.
#
# Модель учитывает перемещение агентов между городами, заражение,
# выздоровление и возможную смерть.

using DrWatson
@quickactivate "../"

using Agents
using DataFrames
using Plots
using JLD2

include("../src/sir_model.jl")

# ## Параметры модели
#
# Зададим основные параметры модели: численность населения по городам,
# интенсивность передачи инфекции, длительность болезни, вероятность смерти,
# вероятность повторного заражения, число начально инфицированных агентов,
# а также число шагов моделирования.

params = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.5, 0.5, 0.5],
    :β_det => [0.05, 0.05, 0.05],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

# ## Инициализация модели
#
# Создадим экземпляр модели с выбранными параметрами.

model = initialize_sir(; params...)

# ## Подготовка структур для сбора результатов
#
# На каждом шаге моделирования будем сохранять:
#
# - номер шага;
# - число восприимчивых;
# - число инфицированных;
# - число выздоровевших;
# - общее число агентов.

times = Int[]
S_vals = Int[]
I_vals = Int[]
R_vals = Int[]
total_vals = Int[]

# ## Проведение моделирования
#
# Запустим модель на заданное число шагов и на каждом шаге сохраним текущие
# значения основных характеристик.

for step = 1:params[:n_steps]
    Agents.step!(model, 1)
    push!(times, step)
    push!(S_vals, susceptible_count(model))
    push!(I_vals, infected_count(model))
    push!(R_vals, recovered_count(model))
    push!(total_vals, total_count(model))
end

# ## Формирование таблиц результатов
#
# Для удобства дальнейшего анализа оформим полученные данные в виде таблиц.

agent_df = DataFrame(
    time = times,
    susceptible = S_vals,
    infected = I_vals,
    recovered = R_vals,
)

model_df = DataFrame(
    time = times,
    total = total_vals,
)

# ## Визуализация результатов
#
# Построим график изменения численности групп во времени.

plot(
    agent_df.time,
    agent_df.susceptible,
    label = "Восприимчивые",
    xlabel = "Дни",
    ylabel = "Количество",
)
plot!(agent_df.time, agent_df.infected, label = "Инфицированные")
plot!(agent_df.time, agent_df.recovered, label = "Выздоровевшие")
plot!(agent_df.time, model_df.total, label = "Всего (включая умерших)", linestyle = :dash)

savefig(plotsdir("sir_basic_dynamics_literate.png"))

# ## Сохранение результатов
#
# Сохраним таблицы результатов в файлы формата JLD2.

@save datadir("sir_basic_agent_literate.jld2") agent_df
@save datadir("sir_basic_model_literate.jld2") model_df

# ## Вывод
#
# В результате моделирования были получены временные ряды по числу
# восприимчивых, инфицированных и выздоровевших агентов, а также построен
# график динамики эпидемического процесса.
