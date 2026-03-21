# # Модель Daisyworld с параметрами
#
# В данной работе расширяется базовая модель Daisyworld за счёт
# варьирования параметров.
#
# Рассматриваются различные комбинации параметров:
# - максимальный возраст ромашек (`max_age`);
# - начальная доля белых ромашек (`init_white`).
#
# Для каждой комбинации параметров выполняется моделирование
# и сохраняются изображения состояния системы на разных шагах.

using DrWatson
@quickactivate "project"

# ## Подключение библиотек

using Agents
using DataFrames
using Plots
using CairoMakie

# ## Подключение модели

include(srcdir("daisyworld.jl"))

# ## Параметры эксперимента

param_dict = Dict(
    :griddims => (30, 30),
    :max_age => [25, 40],
    :init_white => [0.2, 0.8],
    :init_black => 0.2,
    :albedo_white => 0.75,
    :albedo_black => 0.25,
    :surface_albedo => 0.4,
    :solar_change => 0.005,
    :solar_luminosity => 1.0,
    :scenario => :default,
    :seed => 165,
)

# ## Генерация комбинаций параметров

params_list = dict_list(param_dict)

# ## Проведение экспериментов

for params in params_list

    # Создание модели с текущими параметрами
    model = daisyworld(; params...)

    # Цвет ромашек определяется их типом
    daisycolor(a::Daisy) = a.breed

    plotkwargs = (
        agent_color = daisycolor,
        agent_size = 20,
        agent_marker = '✿',
        heatarray = :temperature,
        heatkwargs = (colorrange = (-20, 60),),
    )

    # --- Начальное состояние ---
    plt1, _ = abmplot(model; plotkwargs...)

    # --- Через 5 шагов ---
    step!(model, 5)
    plt2, _ = abmplot(model; heatarray = model.temperature, plotkwargs...)

    # --- Через 40 шагов ---
    step!(model, 40)
    plt3, _ = abmplot(model; heatarray = model.temperature, plotkwargs...)

    # ## Сохранение результатов

    plt1_name = savename("daisyworld", params) * "_step01.png"
    plt2_name = savename("daisyworld", params) * "_step05.png"
    plt3_name = savename("daisyworld", params) * "_step40.png"

    save(plotsdir(plt1_name), plt1)
    save(plotsdir(plt2_name), plt2)
    save(plotsdir(plt3_name), plt3)
end

println("Готово: изображения с параметрами сохранены в папку plots")

# ## Анализ результатов
#
# По результатам моделирования можно сделать следующие выводы:
#
# 1. Изменение начальной доли белых ромашек существенно влияет
#    на начальное распределение агентов и динамику системы.
#
# 2. При большем значении параметра `max_age` популяция становится
#    более устойчивой, так как ромашки дольше живут.
#
# 3. Несмотря на различия в начальных условиях, система стремится
#    к состоянию, близкому к равновесию.
#
# 4. Наблюдается эффект саморегуляции, при котором взаимодействие
#    агентов и среды приводит к стабилизации температурного режима.
#
# Таким образом, модель Daisyworld демонстрирует зависимость
# поведения системы от параметров, сохраняя при этом общие свойства
# самоорганизации.
