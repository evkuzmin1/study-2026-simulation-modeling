#!/usr/bin/env julia
using DrWatson
@quickactivate
using Literate

function main()
    if length(ARGS) == 0
        println("Использование: julia tangle.jl <путь_к_скрипту>")
        return
    end

    script_path = ARGS[1]
    if !isfile(script_path)
        error("Файл не найден: $script_path")
    end

    script_name = splitext(basename(script_path))[1]

    scripts_dir = scriptsdir(script_name)
    Literate.script(script_path, scripts_dir; credit=false)
    println("✓ Чистый скрипт: $(scripts_dir)/$(script_name).jl")

    quarto_dir = projectdir("markdown", script_name)
    Literate.markdown(
        script_path,
        quarto_dir;
        flavor=Literate.QuartoFlavor(),
        name=script_name,
        credit=false
    )
    println("✓ Quarto: $(quarto_dir)/$(script_name).qmd")

    notebooks_dir = projectdir("notebooks", script_name)
    Literate.notebook(
        script_path,
        notebooks_dir;
        name=script_name,
        execute=false,
        credit=false
    )
    println("✓ Notebook: $(notebooks_dir)/$(script_name).ipynb")

    println("\nГотово! Все файлы созданы.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
