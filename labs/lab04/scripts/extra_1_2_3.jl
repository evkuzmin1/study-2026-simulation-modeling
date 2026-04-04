# # Дополнительные задания 1–3
# ## Базовый уровень, исследование порога и эффект гетерогенности
#
# В данном файле объединены три дополнительных задания:
#
# - базовый запуск модели и вычисление базового репродуктивного числа;
# - исследование эпидемического порога;
# - анализ эффекта гетерогенности по городам.
#
# Такое объединение удобно, поскольку все три задания связаны
# с параметром заражения `β` и с анализом общей динамики модели SIR.

using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Statistics
using JLD2

include(srcdir("sir_model.jl"))

function main()

# ## 1. Базовый уровень
#
# Сначала выполним запуск модели с параметрами по умолчанию,
# построим график динамики численности `S`, `I`, `R`
# и вычислим базовое репродуктивное число:
#
# $$ R_0 = \frac{\beta}{\gamma}, \quad \gamma = \frac{1}{infection\_period}. $$

params_basic = Dict(
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

model = initialize_sir(; params_basic...)

times = Int[]
S_vals = Int[]
I_vals = Int[]
R_vals = Int[]

for step in 1:params_basic[:n_steps]
    Agents.step!(model, 1)
    push!(times, step)
    push!(S_vals, susceptible_count(model))
    push!(I_vals, infected_count(model))
    push!(R_vals, recovered_count(model))
end

basic_df = DataFrame(
    time = times,
    susceptible = S_vals,
    infected = I_vals,
    recovered = R_vals,
)

γ = 1 / params_basic[:infection_period]
R0 = params_basic[:β_und][1] / γ

p_basic = plot(
    basic_df.time,
    basic_df.susceptible,
    label = "S",
    xlabel = "Дни",
    ylabel = "Численность",
    title = "Базовая динамика SIR",
)
plot!(p_basic, basic_df.time, basic_df.infected, label = "I")
plot!(p_basic, basic_df.time, basic_df.recovered, label = "R")
savefig(p_basic, plotsdir("extra_1_basic_sir.png"))

println("Базовое репродуктивное число R0 = $(round(R0, digits=3))")

# ## 2. Исследование порога
#
# Теперь исследуем, при каком минимальном значении `β`
# возникает эпидемия, то есть пик числа инфицированных превышает 5%
# от общей численности популяции.
#
# Полученный результат сравнивается с теоретическим порогом:
#
# $$ R_0 = 1 \Rightarrow \beta = \gamma. $$

beta_range = 0.05:0.05:1.0
threshold_beta = nothing
threshold_peak = nothing
population_total = sum(params_basic[:Ns])

threshold_results = DataFrame(
    beta = Float64[],
    peak_fraction = Float64[],
)

for beta in beta_range
    model_thr = initialize_sir(;
        Ns = params_basic[:Ns],
        β_und = fill(beta, 3),
        β_det = fill(beta / 10, 3),
        infection_period = params_basic[:infection_period],
        detection_time = params_basic[:detection_time],
        death_rate = params_basic[:death_rate],
        reinfection_probability = params_basic[:reinfection_probability],
        Is = params_basic[:Is],
        seed = params_basic[:seed],
        n_steps = params_basic[:n_steps],
    )

    peak_fraction = 0.0

    for step in 1:params_basic[:n_steps]
        Agents.step!(model_thr, 1)
        frac = infected_count(model_thr) / population_total
        if frac > peak_fraction
            peak_fraction = frac
        end
    end

    push!(threshold_results, (beta, peak_fraction))

    if threshold_beta === nothing && peak_fraction > 0.05
        threshold_beta = beta
        threshold_peak = peak_fraction
    end
end

theoretical_beta = γ

p_threshold = plot(
    threshold_results.beta,
    threshold_results.peak_fraction,
    label = "Пиковая доля I",
    xlabel = "β",
    ylabel = "Доля инфицированных",
    title = "Исследование порога эпидемии",
)
hline!(p_threshold, [0.05], label = "Порог 5%")
vline!(p_threshold, [theoretical_beta], label = "Теоретический порог R₀ = 1")
savefig(p_threshold, plotsdir("extra_2_threshold.png"))

println("Теоретический порог beta = $(round(theoretical_beta, digits=3))")
if threshold_beta !== nothing
    println("Найденный порог beta = $(threshold_beta), пик = $(round(threshold_peak, digits=3))")
else
    println("В диапазоне beta порог не найден")
end

CSV.write(datadir("extra_2_threshold_results.csv"), threshold_results)

# ## 3. Эффект гетерогенности
#
# На этом этапе зададим разные коэффициенты заражения для разных городов
# и посмотрим, как это влияет на общую динамику и на динамику в каждом городе.
#
# Здесь используются значения:
#
# - город 1: `β = 0.2`
# - город 2: `β = 0.5`
# - город 3: `β = 0.8`

params_hetero = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.2, 0.5, 0.8],
    :β_det => [0.02, 0.05, 0.08],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

model_hetero = initialize_sir(; params_hetero...)

hetero_total = DataFrame(
    time = Int[],
    infected = Int[],
)

hetero_city = DataFrame(
    time = Int[],
    city = Int[],
    infected = Int[],
)

for step in 1:params_hetero[:n_steps]
    Agents.step!(model_hetero, 1)

    push!(hetero_total, (step, infected_count(model_hetero)))

    for city in 1:3
        city_inf = count(a.status == :I && a.pos == city for a in allagents(model_hetero))
        push!(hetero_city, (step, city, city_inf))
    end
end

p_total = plot(
    hetero_total.time,
    hetero_total.infected,
    label = "Общая динамика I",
    xlabel = "Дни",
    ylabel = "Число инфицированных",
    title = "Гетерогенность: общая динамика",
)
savefig(p_total, plotsdir("extra_3_heterogeneity_total.png"))

p_city = plot(
    xlabel = "Дни",
    ylabel = "Число инфицированных",
    title = "Гетерогенность: динамика по городам",
)
for city in 1:3
    subdf = hetero_city[hetero_city.city .== city, :]
    plot!(p_city, subdf.time, subdf.infected, label = "Город $city")
end
savefig(p_city, plotsdir("extra_3_heterogeneity_by_city.png"))

CSV.write(datadir("extra_3_heterogeneity_total.csv"), hetero_total)
CSV.write(datadir("extra_3_heterogeneity_by_city.csv"), hetero_city)

save(datadir("extra_1_basic_result.jld2"), Dict(
    "R0" => R0,
    "basic_df" => basic_df,
    "threshold_beta" => threshold_beta,
    "threshold_peak" => threshold_peak,
))

# ## Вывод
#
# В результате выполнения дополнительных заданий 1–3 были:
#
# - получены базовые траектории `S`, `I`, `R`;
# - вычислено базовое репродуктивное число `R₀`;
# - найден порог эпидемии по параметру `β`;
# - исследовано влияние гетерогенности коэффициента заражения между городами.
#
# Это позволило сопоставить теоретические характеристики модели
# с наблюдаемой динамикой и оценить влияние неоднородности параметров
# на развитие эпидемии.

end

main()
