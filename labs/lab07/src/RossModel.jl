module RossModel

using Distributions
using StableRNGs
using DataFrames
using Statistics
using LinearAlgebra

export RossParameters
export run_ross_simulation
export run_ross_replications
export ross_analytic_mttf
export print_ross_summary

"""
    RossParameters

Параметры модели Росса.

Поля:
- `num_operating` — число машин, которые должны постоянно работать;
- `num_spares` — число резервных машин;
- `num_repairers` — число ремонтников;
- `failure_rate` — интенсивность отказа одной работающей машины;
- `repair_rate` — интенсивность ремонта одной машины одним ремонтником;
- `seed` — зерно генератора случайных чисел;
- `max_time` — максимальное время моделирования.
"""
struct RossParameters
    num_operating::Int
    num_spares::Int
    num_repairers::Int
    failure_rate::Float64
    repair_rate::Float64
    seed::Int
    max_time::Float64
end

"""
    RossParameters(; kwargs...)

Конструктор параметров модели Росса со значениями по умолчанию.
"""
function RossParameters(;
    num_operating = 5,
    num_spares = 3,
    num_repairers = 1,
    failure_rate = 0.1,
    repair_rate = 0.5,
    seed = 123,
    max_time = 1000.0,
)
    return RossParameters(
        Int(num_operating),
        Int(num_spares),
        Int(num_repairers),
        Float64(failure_rate),
        Float64(repair_rate),
        Int(seed),
        Float64(max_time),
    )
end

"""
    RossState

Внутреннее состояние модели Росса.

Поля:
- `spares_available` — число доступных резервных машин;
- `repair_queue` — длина очереди на ремонт;
- `repair_completions` — запланированные завершения ремонтов;
- `failed` — флаг отказа системы.
"""
mutable struct RossState
    spares_available::Int
    repair_queue::Int
    repair_completions::Vector{Tuple{Int, Float64}}
    failed::Bool
end

"""
    RossState(params)

Создаёт начальное состояние системы.
"""
function RossState(params::RossParameters)
    return RossState(
        params.num_spares,
        0,
        Tuple{Int, Float64}[],
        false,
    )
end

"""
    busy_repairers(state)

Возвращает число занятых ремонтников.
"""
function busy_repairers(state::RossState)
    return length(state.repair_completions)
end

"""
    find_free_repairer(state, params)

Находит номер свободного ремонтника.
"""
function find_free_repairer(state::RossState, params::RossParameters)
    busy_ids = [item[1] for item in state.repair_completions]

    for id in 1:params.num_repairers
        if !(id in busy_ids)
            return id
        end
    end

    return 0
end

"""
    start_repair!(state, params, current_time, repair_dist, rng)

Запускает ремонт одной сломанной машины, если есть свободный ремонтник.
"""
function start_repair!(
    state::RossState,
    params::RossParameters,
    current_time::Float64,
    repair_dist,
    rng,
)
    if busy_repairers(state) >= params.num_repairers
        return false
    end

    repairer_id = find_free_repairer(state, params)

    if repairer_id == 0
        return false
    end

    repair_time = rand(rng, repair_dist)
    completion_time = current_time + repair_time

    push!(state.repair_completions, (repairer_id, completion_time))

    return true
end

"""
    next_repair_completion(state)

Возвращает индекс и время ближайшего завершения ремонта.
"""
function next_repair_completion(state::RossState)
    if isempty(state.repair_completions)
        return 0, Inf
    end

    completion_times = [item[2] for item in state.repair_completions]
    idx = argmin(completion_times)

    return idx, completion_times[idx]
end

"""
    record_state!(history, event, time, params, state)

Добавляет текущее состояние системы в историю моделирования.
"""
function record_state!(
    history::Vector{NamedTuple},
    event::String,
    time::Float64,
    params::RossParameters,
    state::RossState,
)
    push!(
        history,
        (
            time = Float64(time),
            event = event,
            operating_machines = Int(params.num_operating),
            spares_available = Int(state.spares_available),
            repair_queue = Int(state.repair_queue),
            repairers_busy = Int(busy_repairers(state)),
            broken_total = Int(params.num_spares - state.spares_available),
            failed = Bool(state.failed),
        ),
    )

    return nothing
end

"""
    run_ross_simulation(params)

Запускает одну симуляцию модели Росса.

Логика модели:
1. в системе постоянно должны работать `num_operating` машин;
2. при отказе работающей машины используется резервная машина;
3. сломанная машина отправляется в ремонт;
4. если свободного ремонтника нет, машина становится в очередь;
5. если отказ происходит при отсутствии резерва, система считается отказавшей.

Возвращает именованный кортеж:
- `history` — история изменения состояния системы;
- `metrics` — основные показатели моделирования;
- `params` — использованные параметры.
"""
function run_ross_simulation(params::RossParameters)
    rng = StableRNG(params.seed)

    # Отказы происходят среди работающих машин.
    # Так как одновременно должно работать num_operating машин,
    # общий поток отказов имеет интенсивность num_operating * failure_rate.
    total_failure_rate = params.num_operating * params.failure_rate

    failure_dist = Exponential(1.0 / total_failure_rate)
    repair_dist = Exponential(1.0 / params.repair_rate)

    state = RossState(params)
    history = NamedTuple[]

    current_time = 0.0
    next_failure_time = rand(rng, failure_dist)

    record_state!(history, "start", current_time, params, state)

    while current_time < params.max_time && !state.failed
        repair_idx, next_repair_time = next_repair_completion(state)

        next_event_time = min(next_failure_time, next_repair_time)

        # Если следующее событие выходит за предел max_time,
        # моделирование останавливается как цензурированное.
        if next_event_time > params.max_time
            current_time = params.max_time
            record_state!(history, "censored", current_time, params, state)
            break
        end

        current_time = next_event_time

        if next_failure_time <= next_repair_time
            # Событие отказа машины.

            if state.spares_available == 0
                # Резервных машин нет, поэтому система отказывает.
                state.failed = true
                record_state!(history, "system_failure", current_time, params, state)
                break
            end

            # Резервная машина заменяет отказавшую.
            state.spares_available -= 1

            # Сломанная машина отправляется в ремонт или в очередь.
            started = start_repair!(
                state,
                params,
                current_time,
                repair_dist,
                rng,
            )

            if started
                record_state!(
                    history,
                    "machine_failure_start_repair",
                    current_time,
                    params,
                    state,
                )
            else
                state.repair_queue += 1
                record_state!(
                    history,
                    "machine_failure_queue_repair",
                    current_time,
                    params,
                    state,
                )
            end

            # Планируем следующий отказ.
            next_failure_time = current_time + rand(rng, failure_dist)
        else
            # Событие завершения ремонта.

            deleteat!(state.repair_completions, repair_idx)

            # Отремонтированная машина возвращается в резерв.
            state.spares_available += 1

            if state.repair_queue > 0
                # Если есть очередь на ремонт, следующий ремонт начинается сразу.
                state.repair_queue -= 1

                start_repair!(
                    state,
                    params,
                    current_time,
                    repair_dist,
                    rng,
                )

                record_state!(
                    history,
                    "repair_complete_start_next",
                    current_time,
                    params,
                    state,
                )
            else
                record_state!(
                    history,
                    "repair_complete",
                    current_time,
                    params,
                    state,
                )
            end
        end
    end

    history_df = DataFrame(history)
    metrics_df = build_ross_metrics(params, history_df)

    return (
        history = history_df,
        metrics = metrics_df,
        params = params,
    )
end

"""
    run_ross_simulation(; kwargs...)

Удобный запуск модели без явного создания `RossParameters`.
"""
function run_ross_simulation(; kwargs...)
    params = RossParameters(; kwargs...)
    return run_ross_simulation(params)
end

"""
    build_ross_metrics(params, history_df)

Рассчитывает основные метрики модели Росса.
"""
function build_ross_metrics(params::RossParameters, history_df::DataFrame)
    if nrow(history_df) == 0
        return DataFrame()
    end

    final_time = history_df.time[end]
    failed = history_df.failed[end]

    avg_queue = time_weighted_average(
        history_df.time,
        history_df.repair_queue,
    )

    avg_busy_repairers = time_weighted_average(
        history_df.time,
        history_df.repairers_busy,
    )

    avg_spares_available = time_weighted_average(
        history_df.time,
        history_df.spares_available,
    )

    repairer_utilization = avg_busy_repairers / params.num_repairers

    max_queue = maximum(history_df.repair_queue)
    max_busy_repairers = maximum(history_df.repairers_busy)

    analytic_mttf = ross_analytic_mttf(params)

    return DataFrame(
        num_operating = [params.num_operating],
        num_spares = [params.num_spares],
        num_repairers = [params.num_repairers],
        failure_rate = [params.failure_rate],
        repair_rate = [params.repair_rate],
        seed = [params.seed],
        time_to_failure = [final_time],
        failed = [failed],
        avg_repair_queue = [avg_queue],
        max_repair_queue = [max_queue],
        avg_busy_repairers = [avg_busy_repairers],
        max_busy_repairers = [max_busy_repairers],
        repairer_utilization = [repairer_utilization],
        avg_spares_available = [avg_spares_available],
        analytic_mttf = [analytic_mttf],
    )
end

"""
    time_weighted_average(times, values)

Считает среднее значение величины по времени.

Значение на интервале [t_i, t_{i+1}] считается равным values[i].
"""
function time_weighted_average(times, values)
    n = length(times)

    if n <= 1
        return Float64(values[1])
    end

    total_time = times[end] - times[1]

    if total_time <= 0
        return Float64(values[end])
    end

    acc = 0.0

    for i in 1:(n - 1)
        dt = times[i + 1] - times[i]
        acc += Float64(values[i]) * dt
    end

    return acc / total_time
end

"""
    ross_analytic_mttf(params)

Вычисляет аналитическую оценку среднего времени до отказа системы.

Используется марковская модель по числу доступных резервных машин.
Состояние `s` означает количество доступных резервных машин.

Если `s > 0`, отказ рабочей машины уменьшает число резервных машин.
Если `s = 0`, следующий отказ приводит к отказу всей системы.
Ремонт увеличивает число доступных резервных машин.
"""
function ross_analytic_mttf(params::RossParameters)
    S = params.num_spares
    R = params.num_repairers

    λ = params.num_operating * params.failure_rate
    μ = params.repair_rate

    # Неизвестные: E[0], E[1], ..., E[S]
    # где E[s] — среднее время до отказа при s доступных резервах.
    A = zeros(Float64, S + 1, S + 1)
    b = ones(Float64, S + 1)

    for s in 0:S
        row = s + 1

        broken = S - s
        busy = min(R, broken)
        repair_intensity = busy * μ

        total_rate = λ + repair_intensity

        A[row, row] = total_rate

        # Переход по отказу:
        # если s > 0, переходим в состояние s - 1;
        # если s = 0, отказ ведёт в поглощающее состояние и в систему уравнений
        # дополнительный член не добавляется.
        if s > 0
            A[row, row - 1] -= λ
        end

        # Переход по ремонту:
        # если есть сломанные машины, ремонт увеличивает число резервов.
        if s < S && repair_intensity > 0
            A[row, row + 1] -= repair_intensity
        end
    end

    E = A \ b

    # Начальное состояние: все резервные машины доступны.
    return E[S + 1]
end

"""
    run_ross_replications(params; n_replications=100)

Запускает несколько независимых повторов модели Росса.

Это нужно для оценки среднего времени до отказа системы.
"""
function run_ross_replications(
    params::RossParameters;
    n_replications = 100,
)
    rows = NamedTuple[]

    for i in 1:n_replications
        p = RossParameters(
            num_operating = params.num_operating,
            num_spares = params.num_spares,
            num_repairers = params.num_repairers,
            failure_rate = params.failure_rate,
            repair_rate = params.repair_rate,
            seed = params.seed + i - 1,
            max_time = params.max_time,
        )

        result = run_ross_simulation(p)
        m = result.metrics

        push!(
            rows,
            (
                replication = i,
                seed = p.seed,
                time_to_failure = m.time_to_failure[1],
                failed = m.failed[1],
                avg_repair_queue = m.avg_repair_queue[1],
                repairer_utilization = m.repairer_utilization[1],
            ),
        )
    end

    df = DataFrame(rows)

    summary = DataFrame(
        n_replications = [n_replications],
        mean_time_to_failure = [mean(df.time_to_failure)],
        std_time_to_failure = [std(df.time_to_failure)],
        min_time_to_failure = [minimum(df.time_to_failure)],
        max_time_to_failure = [maximum(df.time_to_failure)],
        mean_repair_queue = [mean(df.avg_repair_queue)],
        mean_repairer_utilization = [mean(df.repairer_utilization)],
        analytic_mttf = [ross_analytic_mttf(params)],
    )

    return (
        replications = df,
        summary = summary,
        params = params,
    )
end

"""
    print_ross_summary(result)

Печатает краткую сводку по результатам одной симуляции.
"""
function print_ross_summary(result)
    metrics = result.metrics

    if nrow(metrics) == 0
        println("Нет данных для вывода.")
        return nothing
    end

    println("Ross model simulation summary")
    println("="^50)
    println("Operating machines: ", metrics.num_operating[1])
    println("Spare machines: ", metrics.num_spares[1])
    println("Repairers: ", metrics.num_repairers[1])
    println("Failure rate: ", metrics.failure_rate[1])
    println("Repair rate: ", metrics.repair_rate[1])
    println("Time to failure: ", round(metrics.time_to_failure[1], digits = 4))
    println("System failed: ", metrics.failed[1])
    println("Average repair queue: ", round(metrics.avg_repair_queue[1], digits = 4))
    println("Max repair queue: ", metrics.max_repair_queue[1])
    println("Repairer utilization: ", round(metrics.repairer_utilization[1], digits = 4))
    println("Analytic MTTF: ", round(metrics.analytic_mttf[1], digits = 4))

    return nothing
end

end # module
