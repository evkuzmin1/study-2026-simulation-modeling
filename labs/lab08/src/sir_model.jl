module SIRModel

using Random
using Distributions
using DataFrames

export SIRParameters,
       SIRPerson,
       SIRSimulationResult,
       sir_basic_reproduction_number,
       initialize_population,
       simulate_sir_des,
       simulate_sir_des_vaccination,
       result_dataframe,
       events_dataframe,
       summary_dataframe

struct SIRParameters
    S0::Int
    I0::Int
    R0::Int
    beta::Float64
    c::Float64
    gamma::Float64
    tmax::Float64
    seed::Int
end

mutable struct SIRPerson
    id::Int
    status::Symbol
end

struct SIRSimulationResult
    params::SIRParameters
    time::Vector{Float64}
    S::Vector{Int}
    I::Vector{Int}
    R::Vector{Int}
    events::DataFrame
end

# Базовое репродуктивное число.
function sir_basic_reproduction_number(params::SIRParameters)
    return params.beta * params.c / params.gamma
end

# Создание начальной популяции.
function initialize_population(params::SIRParameters)
    population = SIRPerson[]
    id = 1

    for _ in 1:params.S0
        push!(population, SIRPerson(id, :S))
        id += 1
    end

    for _ in 1:params.I0
        push!(population, SIRPerson(id, :I))
        id += 1
    end

    for _ in 1:params.R0
        push!(population, SIRPerson(id, :R))
        id += 1
    end

    return population
end

# Подсчёт количества агентов в состояниях S, I и R.
function count_statuses(population::Vector{SIRPerson})
    S = count(person -> person.status == :S, population)
    I = count(person -> person.status == :I, population)
    R = count(person -> person.status == :R, population)

    return S, I, R
end

# Выбор случайного агента с заданным статусом.
function random_person_with_status(
    rng::AbstractRNG,
    population::Vector{SIRPerson},
    status::Symbol,
)
    indexes = findall(person -> person.status == status, population)

    if isempty(indexes)
        return nothing
    end

    return population[rand(rng, indexes)]
end

# Добавление текущего состояния во временные ряды.
function push_state!(
    time::Vector{Float64},
    S_values::Vector{Int},
    I_values::Vector{Int},
    R_values::Vector{Int},
    t::Float64,
    population::Vector{SIRPerson},
)
    S, I, R = count_statuses(population)

    push!(time, t)
    push!(S_values, S)
    push!(I_values, I)
    push!(R_values, R)

    return nothing
end

# Добавление события в таблицу событий.
function add_event!(
    events::DataFrame,
    t::Float64,
    event::Symbol,
    person_id::Int,
    population::Vector{SIRPerson},
)
    S, I, R = count_statuses(population)

    push!(
        events,
        (
            t = t,
            event = event,
            person_id = person_id,
            S = S,
            I = I,
            R = R,
        ),
    )

    return nothing
end

# Базовая дискретно-событийная SIR-модель.
function simulate_sir_des(params::SIRParameters)
    rng = MersenneTwister(params.seed)
    population = initialize_population(params)

    time = Float64[]
    S_values = Int[]
    I_values = Int[]
    R_values = Int[]

    events = DataFrame(
        t = Float64[],
        event = Symbol[],
        person_id = Int[],
        S = Int[],
        I = Int[],
        R = Int[],
    )

    t = 0.0
    N = params.S0 + params.I0 + params.R0

    push_state!(time, S_values, I_values, R_values, t, population)

    while t < params.tmax
        S, I, _ = count_statuses(population)

        if I == 0
            break
        end

        infection_rate = params.beta * params.c * S * I / N
        recovery_rate = params.gamma * I
        total_rate = infection_rate + recovery_rate

        if total_rate <= 0.0
            break
        end

        dt = rand(rng, Exponential(1.0 / total_rate))
        next_t = t + dt

        if next_t > params.tmax
            break
        end

        t = next_t

        if rand(rng) < infection_rate / total_rate && S > 0
            person = random_person_with_status(rng, population, :S)

            if person !== nothing
                person.status = :I
                add_event!(events, t, :infection, person.id, population)
            end
        else
            person = random_person_with_status(rng, population, :I)

            if person !== nothing
                person.status = :R
                add_event!(events, t, :recovery, person.id, population)
            end
        end

        push_state!(time, S_values, I_values, R_values, t, population)
    end

    if time[end] < params.tmax
        push_state!(time, S_values, I_values, R_values, params.tmax, population)
    end

    return SIRSimulationResult(params, time, S_values, I_values, R_values, events)
end

# Дискретно-событийная SIR-модель со сценарием вакцинации.
function simulate_sir_des_vaccination(
    params::SIRParameters;
    vaccination_time::Float64 = 10.0,
    vaccination_fraction::Float64 = 0.2,
)
    rng = MersenneTwister(params.seed)
    population = initialize_population(params)

    time = Float64[]
    S_values = Int[]
    I_values = Int[]
    R_values = Int[]

    events = DataFrame(
        t = Float64[],
        event = Symbol[],
        person_id = Int[],
        S = Int[],
        I = Int[],
        R = Int[],
    )

    t = 0.0
    N = params.S0 + params.I0 + params.R0
    vaccination_done = false

    push_state!(time, S_values, I_values, R_values, t, population)

    while t < params.tmax
        S, I, _ = count_statuses(population)

        if I == 0
            break
        end

        infection_rate = params.beta * params.c * S * I / N
        recovery_rate = params.gamma * I
        total_rate = infection_rate + recovery_rate

        if total_rate <= 0.0
            break
        end

        dt = rand(rng, Exponential(1.0 / total_rate))
        next_t = t + dt

        # Вакцинация выполняется как отдельное событие.
        if !vaccination_done &&
           t < vaccination_time &&
           vaccination_time <= next_t &&
           vaccination_time <= params.tmax

            t = vaccination_time

            susceptible_indexes = findall(
                person -> person.status == :S,
                population,
            )

            vaccination_fraction = clamp(vaccination_fraction, 0.0, 1.0)
            vaccinated_count = floor(
                Int,
                vaccination_fraction * length(susceptible_indexes),
            )

            if vaccinated_count > 0
                selected_indexes = rand(
                    rng,
                    susceptible_indexes,
                    vaccinated_count,
                )

                for index in selected_indexes
                    population[index].status = :R
                end
            end

            vaccination_done = true

            add_event!(events, t, :vaccination, 0, population)
            push_state!(time, S_values, I_values, R_values, t, population)

            continue
        end

        if next_t > params.tmax
            break
        end

        t = next_t

        if rand(rng) < infection_rate / total_rate && S > 0
            person = random_person_with_status(rng, population, :S)

            if person !== nothing
                person.status = :I
                add_event!(events, t, :infection, person.id, population)
            end
        else
            person = random_person_with_status(rng, population, :I)

            if person !== nothing
                person.status = :R
                add_event!(events, t, :recovery, person.id, population)
            end
        end

        push_state!(time, S_values, I_values, R_values, t, population)
    end

    if time[end] < params.tmax
        push_state!(time, S_values, I_values, R_values, params.tmax, population)
    end

    return SIRSimulationResult(params, time, S_values, I_values, R_values, events)
end

# Таблица временных рядов S, I и R.
function result_dataframe(result::SIRSimulationResult)
    return DataFrame(
        t = result.time,
        S = result.S,
        I = result.I,
        R = result.R,
    )
end

# Таблица событий модели.
function events_dataframe(result::SIRSimulationResult)
    return result.events
end

# Краткая итоговая таблица по одному запуску.
function summary_dataframe(result::SIRSimulationResult)
    params = result.params

    peak_I, peak_index = findmax(result.I)
    peak_time = result.time[peak_index]

    final_S = result.S[end]
    final_I = result.I[end]
    final_R = result.R[end]

    return DataFrame(
        S0 = [params.S0],
        I0 = [params.I0],
        R0 = [params.R0],
        beta = [params.beta],
        c = [params.c],
        gamma = [params.gamma],
        reproduction_number = [sir_basic_reproduction_number(params)],
        tmax = [params.tmax],
        seed = [params.seed],
        peak_I = [peak_I],
        peak_time = [peak_time],
        final_S = [final_S],
        final_I = [final_I],
        final_R = [final_R],
        final_size = [final_R - params.R0],
        epidemic_duration = [result.time[end]],
        events_count = [nrow(result.events)],
    )
end

end
