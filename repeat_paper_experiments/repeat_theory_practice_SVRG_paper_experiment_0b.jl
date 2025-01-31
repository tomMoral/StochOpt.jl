"""
### "Towards closing the gap between the theory and practice of SVRG", O. Sebbouh, S. Jelassi, N. Gazagnadou, F. Bach, R. M. Gower (2019)

## --- EXPERIMENT 0.B ---
Goal: Testing the optimality of our optimal inner loop size m* with b = 1 and corresponding step size gamma^*(b).

## --- THINGS TO CHANGE BEFORE RUNNING ---
- line 44-50: enter your full path to the "StochOpt.jl/" repository in the *path* variable

## --- HOW TO RUN THE CODE ---
To run this experiment, open a terminal, go into the "StochOpt.jl/" repository and run the following command:
>julia -p <number_of_processor_to_add> repeat_paper_experiments/repeat_theory_practice_SVRG_paper_experiment_0b.jl <boolean>
where <number_of_processor_to_add> has to be replaced by the user.
-If <boolean> == false, only the first problem (ijcnn1_full + column-scaling + lambda=1e-1) is launched
-Elseif <boolean> == true, all XX problems are launched

## --- EXAMPLE OF RUNNING TIME ---
Running time of the first problem only when adding XX processors on XXXX
XXXX, around XXmin
Running time of all problems when adding XX processors on XXXX
XXXX, around XXmin

## --- SAVED FILES ---
For each problem (data set + scaling process + regularization)
- the empirical total complexity v.s. inner loop size plots are saved in ".pdf" format in the "./experiments/theory_practice_SVRG/exp0b/figures/" folder
- the results of the simulations (inner loop grid, empirical complexities, optimal empirical inner loop size, etc.) are saved in ".jld" format in the "./experiments/theory_practice_SVRG/exp0b/outputs/" folder
"""

## General settings
max_epochs = 10^8
max_time = 60.0*60.0*10.0
precision = 10.0^(-4) # 10.0^(-6)

## Bash input
# all_problems = parse(Bool, ARGS[1]) # run 1 (false) or all the 12 problems (true)
# problems = parse.(Int64, ARGS)
machine = ARGS[1]
problems = [parse(Int64, ARGS[2])]
println("problems: ", problems)

using Distributed

@everywhere begin
    if machine == "lame10"
        path = "/cal/homes/ngazagnadou/StochOpt.jl/"   # lame10
    elseif machine == "lame23"
        path = "/home/infres/ngazagnadou/StochOpt.jl/" # lame23
    elseif machine == "home"
        path = "/home/nidham/phd/StochOpt.jl/"         # local
    else
        error("Unkown machine name (first argument)")
    end
    println("path: ", path)

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
    # gr()
    pyplot() # No problem with pyplot when called in @everywhere statement
end

## Create saving directories if not existing
save_path = "$(path)experiments/theory_practice_SVRG/"
#region
if !isdir(save_path)
    mkdir(save_path)
end
save_path = "$(save_path)exp0b/"
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
numsimu = 1 # number of runs of Free-SVRG for averaging the empirical complexity
# if all_problems
#     problems = 1:10
# else
#     problems = 1:1
# end

datasets = ["ijcnn1_full", "ijcnn1_full",                       # scaled,   n = 141,691, d =     22
            "YearPredictionMSD_full", "YearPredictionMSD_full", # scaled,   n = 515,345, d =     90
            "covtype_binary", "covtype_binary",                 # scaled,   n = 581,012, d =     54
            "slice", "slice",                                   # scaled,   n =  53,500, d =    384
            "real-sim", "real-sim",                             # unscaled, n =  72,309, d = 20,958
            "a1a_full", "a1a_full",                             # unscaled,       n =  32,561, d =    123
            "colon-cancer", "colon-cancer",                     # already scaled, n =   2,000, d =     62
            "leukemia_full", "leukemia_full"]                   # already scaled, n =      62, d =  7,129

scalings = ["column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "none", "none",
            "none", "none",
            "none", "none",
            "none", "none"]

lambdas = [10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3)]

## In the following table, set smaller values for finer estimations (yet, longer simulations)
skip_multipliers = [0.001,      # 1)  ijcnn1_full + scaled + 1e-1
                    0.001,      # 2)  ijcnn1_full + scaled + 1e-3
                    0.01,       # 3)  YearPredictionMSD_full + scaled + 1e-1
                    0.01,       # 4)  YearPredictionMSD_full + scaled + 1e-3
                    0.01,       # 5)  covtype_binary + scaled + 1e-1
                    1.0,        # 6)  covtype_binary + scaled + 1e-3
                    0.5,        # 7)  slice + scaled + 1e-1
                    1.0,        # 8)  slice + scaled + 1e-3
                    1.0,        # 9)  real-sim + unscaled + 1e-1
                    1.0,        # 10) real-sim + unscaled + 1e-3
                    1.0,        # 11) a1a_full + unscaled + 1e-1
                    1.0,        # 12) a1a_full + unscaled + 1e-3
                    1.0,        # 13) colon-cancer + unscaled + 1e-1
                    1.0,        # 14) colon-cancer + unscaled + 1e-3
                    1.0,        # 15) leukemia_full + unscaled + 1e-1
                    1.0]        # 16) leukemia_full + unscaled + 1e-3

## Grid of inner loop values
grids = [[2^0, 2^4, 2^8, 2^12, 2^14, 2^15, 2^16, 2^17, 2^18, 2^19, 2^20],
         [2^0, 2^2, 2^4, 2^6, 2^7, 2^8, 2^9, 2^10, 2^11, 2^12, 2^13, 2^14, 2^16, 2^18, 2^19],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^8, 2^12, 2^16],
         [2^0, 2^4, 2^8, 2^12, 32561], # 11) a1a_full + unscaled + 1e-1
         [2^0, 2^4, 2^8, 2^12, 32561], # 12) a1a_full + unscaled + 1e-3
         [2^0, 2^2, 2^4, 62], # 13) colon-cancer + unscaled + 1e-1
         [2^0, 2^2, 2^4, 62], # 14) colon-cancer + unscaled + 1e-3
         [2^0, 2^2, 2^4, 72], # 15) leukemia_full + unscaled + 1e-1
         [2^0, 2^2, 2^4, 72]] # 16) leukemia_full + unscaled + 1e-3

@time begin
@sync @distributed for idx_prob in problems
    data = datasets[idx_prob];
    scaling = scalings[idx_prob];
    lambda = lambdas[idx_prob];
    println("EXPERIMENT : ", idx_prob, " over ", length(problems))
    @printf "Inputs: %s + %s + %1.1e \n" data scaling lambda;

    Random.seed!(1)

    ## Loading the data
    println("--- Loading data ---")
    data_path = "$(path)data/";
    X, y = loadDataset(data_path, data)

    ## Setting up the problem
    println("\n--- Setting up the selected problem ---")
    options = set_options(tol=precision, max_iter=10^8,
                          max_epocs=max_epochs,
                          max_time=max_time,
                          skip_error_calculation=10^4,
                          batchsize=1,
                          regularizor_parameter = "normalized",
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
    d = prob.numfeatures
    mu = prob.mu
    Lmax = prob.Lmax
    L = prob.L

    ## Computing theoretical optimal inner loop for 1-nice sampling
    m_theoretical = round(Int, 3*Lmax / mu) # optimal m for Free-SVRG whith 1-nice sampling (\cL = Lmax)
    println("Theoretical optimal inner loop = ", m_theoretical)

    ## Computing the optimal empirical inner loop size over a grid
    inner_loop_grid = grids[idx_prob]
    # if data == "ijcnn1_full" && lambda == 1e-1
    #     inner_loop_grid = [2^0, 2^2, 2^4, 2^6, 2^7, 2^8, 2^9, 2^10, 2^11, 2^12, 2^13, 2^14, 2^16, 2^18, 2^20]
    # elseif data == "slice"
    #     inner_loop_grid = [2^0, 2^1, 2^2, 2^3, 2^4, 2^5, 2^6, 2^7, 2^8, 2^9, 2^10, 2^11, 2^12, 2^13, 2^14, 2^15, 2^16, 2^17, 2^18, 2^19]
    # elseif m_theoretical == 1
    #     inner_loop_grid = [m_theoretical, round(Int, m_theoretical*2^2), round(Int, m_theoretical*2^4), round(Int, m_theoretical*2^6)]
    # else
    #     inner_loop_grid = [max(round(Int, m_theoretical*2^(-4)), 1), m_theoretical, round(Int, m_theoretical*2^4)]
    # end

    println("---------------------------------- INNER LOOP GRID ------------------------------------------")
    println(inner_loop_grid)
    println("---------------------------------------------------------------------------------------------")

    OUTPUTS, itercomplex = simulate_Free_SVRG_nice_inner_loop(prob, inner_loop_grid, options, numsimu=numsimu, skip_multiplier=skip_multipliers[idx_prob], path=save_path)

    ## Checking that all simulations reached tolerance
    fails = [OUTPUTS[i].fail for i=1:length(inner_loop_grid)*numsimu]
    if all(s->(string(s)=="tol-reached"), fails)
        println("Tolerance always reached")
    else
        println("Some total complexities might be threshold because of reached maximal time")
    end

    ## Computing the empirical complexity
    empcomplex = reshape([n*OUTPUTS[i].epochs[end] for i=1:length(inner_loop_grid)*numsimu], length(inner_loop_grid)) # number of stochastic gradients computed
    min_empcomplex, idx_min = findmin(empcomplex)
    m_empirical = inner_loop_grid[idx_min]

    ## Saving the result of the simulations
    probname = replace(replace(prob.name, r"[\/]" => "-"), "." => "_")
    savename = string(probname, "-exp0b-", numsimu, "-avg")
    savename = string(savename, "_skip_mult_", replace(string(skip_multipliers[idx_prob]), "." => "_")) # Extra suffix to check which skip values to keep
    if numsimu == 1
        save("$(save_path)data/$(savename).jld",
        "options", options, "inner_loop_grid", inner_loop_grid,
        "itercomplex", itercomplex, "empcomplex", empcomplex,
        "m_theoretical", m_theoretical, "m_empirical", m_empirical)
    end

    ## Plotting total complexity vs inner loop size
    legendpos = :topleft
    pyplot()
    exp_number = 2 # grid of inner loop sizes
    plot_empirical_complexity_SVRG(prob, exp_number, inner_loop_grid, empcomplex, m_theoretical, m_empirical, save_path, skip_multiplier=skip_multipliers[idx_prob], legendpos=legendpos)

    println("Theoretical optimal inner loop = ", m_theoretical)
    println("Empirical optimal inner loop = ", m_empirical, "\n\n")
end
end

println("\n\n--- EXPERIMENT 0.B FINISHED ---")