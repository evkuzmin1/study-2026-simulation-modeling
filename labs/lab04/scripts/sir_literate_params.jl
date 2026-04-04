# # Лабораторная работа 4
# ## Реализация модели SIR в агентном подходе
# ## Версия с набором параметров
#
# В данной версии рассматривается не один запуск модели, а несколько
# сценариев с различными параметрами распространения инфекции.
# Это позволяет сравнить динамику эпидемического процесса во времени
# для разных значений коэффициента передачи инфекции.

using DrWatson
@quickactivate "../"

using Agents
using DataFrames
using Plots
using JLD2

include("../src/sir_model.jl")

# ## Базовые параметры модели
#
# Зададим параметры, которые будут одинаковыми для всех сценариев.

base_params = Dict(
    :Ns => [1000, 1000, 1000],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

# ## Набор параметров
#
# Рассмотрим несколько сценариев с разными значениями коэффициента
# передачи инфекции у невыявленных инфицированных. Для выявленных
# инфицированных коэффициент передачи примем в 10 раз меньше.

param_sets = [
    (name = "Сценарий 1: β = 0.3", β_und = [0.3, 0.3, 0.3], β_det = [0.03, 0.03, 0.03]),
    (name = "Сценарий 2: β = 0.5", β_und = [0.5, 0.5, 0.5], β_det = [0.05, 0.05, 0.05]),
    (name = "Сценарий 3: β = 0.7", β_und = [0.7, 0.7, 0.7], β_det = [0.07, 0.07, 0.07]),
]

# ## Функция запуска одного сценария
#
# Для каждого набора параметров выполняется отдельное моделирование
# и сохраняются временные ряды основных характеристик.

function run_scenario(base_params, β_und, β_det, scenario_name)
    params = Dict(
        :Ns => base_params[:Ns],
        :β_und => β_und,
        :β_det => β_det,
        :infection_period => base_params[:infection_period],
        :detection_time => base_params[:detection_time],
        :death_rate => base_params[:death_rate],
        :reinfection_probability => base_params[:reinfection_probability],
        :Is => base_params[:Is],
        :seed => base_params[:seed],
        :n_steps => base_params[:n_steps],
    )

    model = initialize_sir(; params...)

    times = Int[]
    S_vals = Int[]
    I_vals = Int[]
    R_vals = Int[]
    total_vals = Int[]

    for step = 1:params[:n_steps]
        Agents.step!(model, 1)
        push!(times, step)
        push!(S_vals, susceptible_count(model))
        push!(I_vals, infected_count(model))
        push!(R_vals, recovered_count(model))
        push!(total_vals, total_count(model))
    end

    agent_df = DataFrame(
        time = times,
        susceptible = S_vals,
        infected = I_vals,
        recovered = R_vals,
        scenario = fill(scenario_name, length(times)),
    )

    model_df = DataFrame(
        time = times,
        total = total_vals,
        scenario = fill(scenario_name, length(times)),
    )

    return agent_df, model_df
end

# ## Выполнение моделирования для всех наборов параметров
#
# Запустим модель для каждого сценария и объединим результаты
# в общие таблицы.

all_agent_df = DataFrame()
all_model_df = DataFrame()

for p in param_sets
    agent_df, model_df = run_scenario(base_params, p.β_und, p.β_det, p.name)
    append!(all_agent_df, agent_df)
    append!(all_model_df, model_df)
end

# ## Просмотр результатов
#
# Выведем первые строки объединённой таблицы.

first(all_agent_df, 10)

# ## Визуализация результатов
#
# Построим сравнительный график числа инфицированных для всех сценариев.

plot(
    xlabel = "Дни",
    ylabel = "Количество инфицированных",
    title = "Сравнение динамики инфицированных для разных параметров",
)

for p in param_sets
    subset_df = all_agent_df[all_agent_df.scenario .== p.name, :]
    plot!(
        subset_df.time,
        subset_df.infected,
        label = p.name,
        lw = 2,
    )
end

savefig(plotsdir("sir_literate_params_infected.png"))

# ## Дополнительный график
#
# Построим также сравнительный график числа выздоровевших.

plot(
    xlabel = "Дни",
    ylabel = "Количество выздоровевших",
    title = "Сравнение динамики выздоровевших для разных параметров",
)

for p in param_sets
    subset_df = all_agent_df[all_agent_df.scenario .== p.name, :]
    plot!(
        subset_df.time,
        subset_df.recovered,
        label = p.name,
        lw = 2,
    )
end

savefig(plotsdir("sir_literate_params_recovered.png"))

# ## Сохранение результатов
#
# Сохраним объединённые результаты в файлы формата JLD2.

@save datadir("sir_literate_params_agent.jld2") all_agent_df
@save datadir("sir_literate_params_model.jld2") all_model_df

# ## Вывод
#
# В результате были выполнены несколько прогонов модели SIR
# для различных значений коэффициента передачи инфекции.
# Это позволило сравнить динамику числа инфицированных и выздоровевших
# агентов во времени для разных сценариев развития эпидемии.
