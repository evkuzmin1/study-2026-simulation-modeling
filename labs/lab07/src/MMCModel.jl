module MMCModel

using ConcurrentSim
using ResumableFunctions
using Distributions
using StableRNGs
using DataFrames
using Statistics

export MMCParameters
export run_mmc_simulation
export mmc_analytics
export print_mmc_summary

"""
    MMCParameters

Структура параметров модели M/M/c.

Поля:
- `num_customers` — количество заявок, которые будут сгенерированы;
- `num_servers` — число параллельных каналов обслуживания;
- `lambda` — интенсивность входящего потока заявок;
- `mu` — интенсивность обслуживания одним каналом;
- `seed` — зерно генератора случайных чисел.
"""
struct MMCParameters
    num_customers::Int
    num_servers::Int
    lambda::Float64
    mu::Float64
    seed::Int
end

"""
    MMCParameters(; num_customers=100, num_servers=2, lambda=0.9, mu=0.5, seed=123)

Конструктор параметров модели M/M/c со значениями по умолчанию.

Параметры по умолчанию близки к примеру из методички:
- `num_servers = 2`;
- `lambda = 0.9`;
- `mu = 0.5`.
"""
function MMCParameters(;
    num_customers = 100,
    num_servers = 2,
    lambda = 0.9,
    mu = 0.5,
    seed = 123,
)
    return MMCParameters(
        Int(num_customers),
        Int(num_servers),
        Float64(lambda),
        Float64(mu),
        Int(seed),
    )
end

"""
    MMCState

Внутренняя структура состояния симуляции.

Она нужна, чтобы собирать события и метрики во время работы модели.
"""
mutable struct MMCState
    events::Vector{NamedTuple}
    customers::Vector{NamedTuple}
    queue_length::Int
    busy_servers::Int
end

"""
    MMCState()

Создаёт пустое состояние симуляции.
"""
function MMCState()
    return MMCState(
        NamedTuple[],
        NamedTuple[],
        0,
        0,
    )
end

"""
    record_event!(state, customer_id, event, time; ...)

Добавляет событие в журнал событий модели.

События:
- `arrival` — заявка прибыла в систему;
- `service_start` — заявка начала обслуживание;
- `departure` — заявка завершила обслуживание.
"""
function record_event!(
    state::MMCState,
    customer_id::Int,
    event::String,
    time::Float64;
    queue_length = state.queue_length,
    busy_servers = state.busy_servers,
    waiting_time = NaN,
    service_time = NaN,
    system_time = NaN,
)
    push!(
        state.events,
        (
            customer_id = customer_id,
            event = event,
            time = time,
            queue_length = Int(queue_length),
            busy_servers = Int(busy_servers),
            waiting_time = Float64(waiting_time),
            service_time = Float64(service_time),
            system_time = Float64(system_time),
        ),
    )

    return nothing
end

"""
    customer_process(env, server, id, arrival_time, service_dist, rng, params, state)

Процесс одной заявки в модели M/M/c.

Логика процесса:
1. заявка появляется в момент `arrival_time`;
2. если все каналы заняты, заявка попадает в очередь;
3. заявка запрашивает свободный канал обслуживания;
4. после получения канала начинается обслуживание;
5. после завершения обслуживания канал освобождается.
"""
@resumable function customer_process(
    env,
    server,
    id::Int,
    arrival_time::Float64,
    service_dist,
    rng,
    params::MMCParameters,
    state::MMCState,
)
    # Заявка появляется в системе в заранее рассчитанный момент времени.
    @yield timeout(env, arrival_time)

    arrival_moment = now(env)

    # Если все серверы заняты, заявка будет ожидать в очереди.
    if state.busy_servers >= params.num_servers
        state.queue_length += 1
    end

    record_event!(
        state,
        id,
        "arrival",
        arrival_moment,
    )

    # Запрос свободного канала обслуживания.
    @yield request(server)

    service_start = now(env)
    waiting_time = service_start - arrival_moment

    # Если заявка реально ожидала, уменьшаем длину очереди.
    if waiting_time > 1.0e-9 && state.queue_length > 0
        state.queue_length -= 1
    end

    state.busy_servers += 1

    service_time = rand(rng, service_dist)

    record_event!(
        state,
        id,
        "service_start",
        service_start;
        waiting_time = waiting_time,
        service_time = service_time,
    )

    # Обслуживание заявки.
    @yield timeout(env, service_time)

    departure_time = now(env)
    system_time = departure_time - arrival_moment

    state.busy_servers -= 1

    record_event!(
        state,
        id,
        "departure",
        departure_time;
        waiting_time = waiting_time,
        service_time = service_time,
        system_time = system_time,
    )

    push!(
        state.customers,
        (
            customer_id = id,
            arrival_time = arrival_moment,
            service_start = service_start,
            departure_time = departure_time,
            waiting_time = waiting_time,
            service_time = service_time,
            system_time = system_time,
        ),
    )

    # Освобождение канала обслуживания.
    @yield unlock(server)

    return nothing
end

"""
    run_mmc_simulation(params)

Запускает дискретно-событийную симуляцию M/M/c.

Возвращает именованный кортеж:
- `events` — журнал событий;
- `customers` — таблица заявок;
- `metrics` — сводные показатели;
- `params` — использованные параметры.
"""
function run_mmc_simulation(params::MMCParameters)
    rng = StableRNG(params.seed)

    # Интервалы между поступлениями заявок имеют экспоненциальное распределение.
    arrival_dist = Exponential(1.0 / params.lambda)

    # Время обслуживания также имеет экспоненциальное распределение.
    service_dist = Exponential(1.0 / params.mu)

    sim = Simulation()
    server = Resource(sim, params.num_servers)

    state = MMCState()

    arrival_time = 0.0

    # Создаём процессы заявок.
    for id in 1:params.num_customers
        arrival_time += rand(rng, arrival_dist)

        @process customer_process(
            sim,
            server,
            id,
            arrival_time,
            service_dist,
            rng,
            params,
            state,
        )
    end

    # Запускаем симуляцию до завершения всех событий.
    run(sim)

    events_df = DataFrame(state.events)
    customers_df = DataFrame(state.customers)

    metrics_df = build_mmc_metrics(params, events_df, customers_df)

    return (
        events = events_df,
        customers = customers_df,
        metrics = metrics_df,
        params = params,
    )
end

"""
    run_mmc_simulation(; kwargs...)

Удобный вариант запуска симуляции без явного создания `MMCParameters`.
"""
function run_mmc_simulation(; kwargs...)
    params = MMCParameters(; kwargs...)
    return run_mmc_simulation(params)
end

"""
    build_mmc_metrics(params, events_df, customers_df)

Вычисляет основные показатели работы системы M/M/c.
"""
function build_mmc_metrics(
    params::MMCParameters,
    events_df::DataFrame,
    customers_df::DataFrame,
)
    if nrow(customers_df) == 0
        return DataFrame()
    end

    last_time = maximum(customers_df.departure_time)

    avg_waiting_time = mean(customers_df.waiting_time)
    avg_service_time = mean(customers_df.service_time)
    avg_system_time = mean(customers_df.system_time)

    max_waiting_time = maximum(customers_df.waiting_time)
    max_queue_length = maximum(events_df.queue_length)
    max_busy_servers = maximum(events_df.busy_servers)

    # Оценка загрузки каналов:
    # суммарное время обслуживания / (число каналов * время наблюдения).
    utilization = sum(customers_df.service_time) /
                  (params.num_servers * last_time)

    metrics = DataFrame(
        num_customers = [params.num_customers],
        num_servers = [params.num_servers],
        lambda = [params.lambda],
        mu = [params.mu],
        rho = [params.lambda / (params.num_servers * params.mu)],
        simulation_time = [last_time],
        avg_waiting_time = [avg_waiting_time],
        avg_service_time = [avg_service_time],
        avg_system_time = [avg_system_time],
        max_waiting_time = [max_waiting_time],
        max_queue_length = [max_queue_length],
        max_busy_servers = [max_busy_servers],
        utilization = [utilization],
    )

    return metrics
end

"""
    mmc_analytics(params)

Вычисляет аналитические характеристики M/M/c для стационарного режима.

Используются стандартные формулы для M/M/c:
- загрузка `rho`;
- вероятность ожидания `P_wait`;
- среднее число заявок в очереди `Lq`;
- среднее время ожидания `Wq`;
- среднее время пребывания в системе `W`;
- среднее число заявок в системе `L`.

Если `rho >= 1`, стационарный режим не существует.
"""
function mmc_analytics(params::MMCParameters)
    λ = params.lambda
    μ = params.mu
    c = params.num_servers

    ρ = λ / (c * μ)

    if ρ >= 1.0
        return DataFrame(
            lambda = [λ],
            mu = [μ],
            num_servers = [c],
            rho = [ρ],
            stable = [false],
            P0 = [NaN],
            P_wait = [NaN],
            Lq = [NaN],
            Wq = [NaN],
            W = [NaN],
            L = [NaN],
        )
    end

    a = λ / μ

    first_sum = sum((a^n) / factorial(n) for n in 0:(c - 1))
    second_part = (a^c) / (factorial(c) * (1.0 - ρ))

    P0 = 1.0 / (first_sum + second_part)
    P_wait = second_part * P0

    Lq = (ρ / (1.0 - ρ)) * P_wait
    Wq = Lq / λ
    W = Wq + 1.0 / μ
    L = λ * W

    return DataFrame(
        lambda = [λ],
        mu = [μ],
        num_servers = [c],
        rho = [ρ],
        stable = [true],
        P0 = [P0],
        P_wait = [P_wait],
        Lq = [Lq],
        Wq = [Wq],
        W = [W],
        L = [L],
    )
end

"""
    print_mmc_summary(result)

Печатает краткую сводку по результатам симуляции.
"""
function print_mmc_summary(result)
    metrics = result.metrics

    if nrow(metrics) == 0
        println("Нет данных для вывода.")
        return nothing
    end

    println("M/M/c simulation summary")
    println("="^50)
    println("Customers: ", metrics.num_customers[1])
    println("Servers: ", metrics.num_servers[1])
    println("lambda: ", metrics.lambda[1])
    println("mu: ", metrics.mu[1])
    println("rho: ", round(metrics.rho[1], digits = 4))
    println("Average waiting time: ", round(metrics.avg_waiting_time[1], digits = 4))
    println("Average service time: ", round(metrics.avg_service_time[1], digits = 4))
    println("Average system time: ", round(metrics.avg_system_time[1], digits = 4))
    println("Max queue length: ", metrics.max_queue_length[1])
    println("Utilization: ", round(metrics.utilization[1], digits = 4))

    return nothing
end

end # module
