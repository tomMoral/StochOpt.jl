"""
### "Towards closing the gap between the theory and practice of SVRG", Francis Bach, Othmane Sebbouh, Nidham Gazagnadou, Robert M. Gower (2019)

## --- EXPERIMENT 1.a ---
Goal: Compare SVRG variants: Bubeck version, Free-SVRG, Leap-SVRG and Loopless-SVRG-Decreasing for nice sampling (b=1).

## --- THINGS TO CHANGE BEFORE RUNNING ---
- line 37: enter your full path to the "StochOpt.jl/" repository in the *path* variable

## --- HOW TO RUN THE CODE ---
To run this experiment, open a terminal, go into the "StochOpt.jl/" repository and run the following command:
>julia -p <number_of_processor_to_add> repeat_paper_experiments/repeat_theory_practice_SVRG_paper_experiment_1a_without_mini-batching.jl <boolean>
where <number_of_processor_to_add> has to be replaced by the user.
- If <boolean> == false, only the first problem (ijcnn1_full + column-scaling + lambda=1e-1) is launched
- Else, <boolean> == true, all XX problems are launched

## --- EXAMPLE OF RUNNING TIME ---
Running time of the first problem only
XXXX, around 5min
Running time of all problems when adding XX processors on XXXX
XXXX, around XXmin

## --- SAVED FILES ---
For each problem (data set + scaling process + regularization)
- the empirical total complexity v.s. mini-batch size plots are saved in ".pdf" format in the "./experiments/theory_practice_SVRG/exp1a/figures/" folder
- the results of the simulations (mini-batch grid, empirical complexities, optimal empirical mini-batch size, etc.) are saved in ".jld" format in the "./experiments/theory_practice_SVRG/exp1a/outputs/" folder
"""

## General settings
max_epochs = 10^8
max_time = 60.0*60.0*24.0
precision = 10.0^(-6)

## File names
details = "final"
# details = "test-rho"
# details = "legend"

using Distributed

## Bash input
path = ARGS[1]
@eval @everywhere path=$path
all_problems = parse(Bool, ARGS[2]) # run 1 (false) or all the 8 problems (true)

# println(workers()) # print available workers

@everywhere begin
    # println(myid(), " : ", ARGS)
    # println(myid(), " : ", path) # print current worker + path
    # path = "/home/infres/ngazagnadou/StochOpt.jl/" # lame23

    using JLD
    using Plots
    using StatsBase
    using Match
    using Combinatorics
    using Random
    using Printf
    using LinearAlgebra
    using Statistics
    using Base64
    using Formatting
    using SharedArrays

    include("$(path)src/StochOpt.jl")

    pyplot() # No problem with pyplot when called in @everywhere statement
end

## Path settings
save_path = "$(path)experiments/theory_practice_SVRG/exp1a/"
#region
# Create saving directories if not existing
if !isdir("$(path)experiments/")
    mkdir("$(path)experiments/")
end
if !isdir("$(path)experiments/theory_practice_SVRG/")
    mkdir("$(path)experiments/theory_practice_SVRG/")
end
if !isdir(save_path)
    mkdir(save_path)
end
if !isdir("$(save_path)data/")
    mkdir("$(save_path)data/")
end
if !isdir("$(save_path)figures/")
    mkdir("$(save_path)figures/")
end
if !isdir("$(save_path)outputs/")
    mkdir("$(save_path)outputs/")
end
#endregion

## Experiments settings
if all_problems
    problems = 1:8
else
    problems = 1:1
end

datasets = ["ijcnn1_full", "ijcnn1_full",                       # scaled,   n = 141,691, d =     22
            "YearPredictionMSD_full", "YearPredictionMSD_full", # scaled,   n = 515,345, d =     90
            "slice", "slice",                                   # scaled,   n =  53,500, d =    384
            "real-sim", "real-sim"]                             # unscaled, n =  72,309, d = 20,958

scalings = ["column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "none", "none"]

lambdas = [10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3)]

## Set smaller number of skipped iteration for finer estimations (yet, longer simulations)
skip_errors = [[700 7000 -2. 7000],     # 1) ijcnn1_full + scaled + 1e-1             25/06 11:14
               [13000 7000 -2. 5000],   # 2) ijcnn1_full + scaled + 1e-3             25/06 11:14
               [50000 30000 -2. 20000], # 3) YearPredictionMSD_full + scaled + 1e-1  25/06 11:14 / 16 epochs
               [60000 40000 -2. 30000], # 4) YearPredictionMSD_full + scaled + 1e-3  25/06 11:14 / 16 epochs
               [50000 40000 -2. 30000], # 5) slice + scaled + 1e-1                   25/06 11:14 / 100 epochs
               [50000 40000 -2. 30000], # 6) slice + scaled + 1e-3                   25/06 11:14 / 100 epochs
               [  10 2000 -2. 4000],    # 7) real-sim + unscaled + 1e-1              25/06 11:14
               [500 5000 -2. 2000]]     # 8) real-sim + unscaled + 1e-3              25/06 11:14

@time @sync @distributed for idx_prob in problems
    data = datasets[idx_prob]
    scaling = scalings[idx_prob]
    lambda = lambdas[idx_prob]
    skip_error = skip_errors[idx_prob]
    println("EXPERIMENT : ", idx_prob, " over ", length(problems))
    @printf "Inputs: %s + %s + %1.1e \n" data scaling lambda

    Random.seed!(1)

    if idx_prob == 3 || idx_prob == 4
        global max_epochs = 16
    elseif idx_prob == 5 || idx_prob == 6
        global max_epochs = 100
    end

    ## Loading the data
    println("--- Loading data ---")
    data_path = "$(path)data/";
    X, y = loadDataset(data_path, data)

    ## Setting up the problem
    println("\n--- Setting up the selected problem ---")
    options = set_options(tol=precision, max_iter=10^8,
                          max_epocs=max_epochs,
                          max_time=max_time,
                          skip_error_calculation=10^5,
                          batchsize=1,
                          regularizor_parameter="normalized",
                          initial_point="zeros", # is fixed not to add more randomness
                          force_continue=false) # force continue if diverging or if tolerance reached

    u = unique(y)
    if length(u) < 2
        error("Wrong number of possible outputs")
    elseif length(u) == 2
        println("Binary output detected: the problem is set to logistic regression")
        prob = load_logistic_from_matrices(X, y, data, options, lambda=lambda, scaling=scaling)
    else
        println("More than three modalities in the outputs: the problem is set to ridge regression")
        prob = load_ridge_regression(X, y, data, options, lambda=lambda, scaling=scaling)
    end

    X = nothing
    y = nothing

    n = prob.numdata

    ## Running methods
    OUTPUTS = [] # list of saved outputs

    ################################################################################
    ################################# SVRG-BUBECK ##################################
    ################################################################################
    ## SVRG-Bubeck with 1-nice sampling ( m = m^*, b = 1, step size = gamma^* )
    numinneriters = -1                 # theoretical inner loop size (m^* = 20*Lmax/mu) set in initiate_SVRG_bubeck
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step size (gamma^* = 1/10*Lmax) set in boot_SVRG_bubeck
    sampling = build_sampling("nice", n, options)
    bubeck = initiate_SVRG_bubeck(prob, options, sampling, numinneriters=numinneriters)

    ## Setting the number of skipped iteration to m/4
    options.skip_error_calculation = skip_error[1] # skip error different for each algo
    # options.skip_error_calculation = round(Int64, bubeck.numinneriters/4)

    # ## Extra parameters for speeding up simulations
    # if idx_prob == 2
    #     println("Adding a max_epochs = 10 to stop Bubeck SVRG running endlessly")
    #     options.max_epocs = 10
    #     options.skip_error_calculation = round(Int64, bubeck.numinneriters/100)
    # elseif idx_prob == 7
    #     options.skip_error_calculation = round(Int64, bubeck.numinneriters/1000)
    # elseif idx_prob == 8
    #     options.skip_error_calculation = round(Int64, bubeck.numinneriters/100000)
    # end

    println("-------------------- WARM UP --------------------")
    tmp = options.max_epocs
    options.max_epocs = 1
    minimizeFunc(prob, bubeck, options)
    options.max_epocs = tmp
    bubeck.reset(prob, bubeck, options)
    println("-------------------------------------------------\n")

    out_bubeck = minimizeFunc(prob, bubeck, options)

    str_m_bubeck = @sprintf "%d" bubeck.numinneriters
    str_step_bubeck = @sprintf "%.2e" bubeck.stepsize
    # out_bubeck.name = latexstring("SVRG-Bubeck \$(m_{Bubeck}^* = $str_m_bubeck, b = 1, \\alpha_{Bubeck}^* = $str_step_bubeck)\$")
    out_bubeck.name = latexstring("SVRG \$(m^* = $str_m_bubeck, b = 1, \\alpha^* = $str_step_bubeck)\$")
    OUTPUTS = [OUTPUTS; out_bubeck]
    options.max_epocs = max_epochs
    println("\n")

    ################################################################################
    ################################## FREE-SVRG ###################################
    ################################################################################
    ## Free-SVRG with 1-nice sampling ( m = n, b = 1, step size = gamma^*(1) )
    numinneriters = n                  # inner loop size set to the number of data points
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step size set in boot_Free_SVRG
    sampling = build_sampling("nice", n, options)
    free = initiate_Free_SVRG(prob, options, sampling, numinneriters=numinneriters, averaged_reference_point=true)

    ## Setting the number of skipped iteration to m/4
    options.skip_error_calculation = skip_error[2] # skip error different for each algo
    # options.skip_error_calculation = round(Int64, free.numinneriters/4)

    out_free = minimizeFunc(prob, free, options)

    str_m_free = @sprintf "%d" free.numinneriters
    str_step_free = @sprintf "%.2e" free.stepsize
    # out_free.name = latexstring("Free-SVRG \$(m = n = $str_m_free, b = 1, \\alpha_{Free}^*(1) = $str_step_free)\$")
    out_free.name = latexstring("Free-SVRG \$(m = n = $str_m_free, b = 1, \\alpha^*(1) = $str_step_free)\$")
    OUTPUTS = [OUTPUTS; out_free]
    println("\n")

    ################################################################################
    ################################### L-SVRG-D ###################################
    ################################################################################
    ## L_SVRG_D with 1-nice sampling ( p = 1/n, b = 1, step size = gamma^*(b) )
    proba = 1/n                        # update probability set to the inverse of the number of data points
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step sizes set in boot_L_SVRG_D
    sampling = build_sampling("nice", n, options)
    decreasing = initiate_L_SVRG_D(prob, options, sampling, proba)

    ## Setting the number of skipped iteration to 1/4*p
    options.skip_error_calculation = skip_error[4] # skip error different for each algo
    # options.skip_error_calculation = round(Int64, 1/(4*proba))

    out_decreasing = minimizeFunc(prob, decreasing, options)

    str_proba_decreasing = @sprintf "%.2e" proba
    str_step_decreasing = @sprintf "%.2e" decreasing.initial_stepsize
    # out_decreasing.name = latexstring("L-SVRG-D \$(p = 1/n = $str_proba_decreasing, b = 1, \\alpha_{Decrease}^*(1) = $str_step_decreasing)\$")
    out_decreasing.name = latexstring("L-SVRG-D \$(p = 1/n = $str_proba_decreasing, b = 1, \\alpha^*(1) = $str_step_decreasing)\$")
    OUTPUTS = [OUTPUTS; out_decreasing]
    println("\n")

    ## Saving outputs and plots
    if path == "/home/infres/ngazagnadou/StochOpt.jl/"
        suffix = "lame23"
    else
        suffix = ""
    end
    savename = replace(replace(prob.name, r"[\/]" => "-"), "." => "_")
    savename = string(savename, "-exp1a-$(suffix)-$(details)")
    save("$(save_path)outputs/$(savename).jld", "OUTPUTS", OUTPUTS)

    pyplot()
    # plot_outputs_Plots(OUTPUTS, prob, options, suffix="-exp1a-$(suffix)-$(max_epochs)_max_epochs", path=save_path, legendpos=:topright, legendfont=6) # Plot and save output
    plot_outputs_Plots(OUTPUTS, prob, options, suffix="-exp1a-$(suffix)-$(details)", path=save_path, nolegend=true)

    println("\nSTRONG CONVEXITY : ", prob.mu, "\n")

end
println("\n\n--- EXPERIMENT 1.A FINISHED ---")