"""
### "Towards closing the gap between the theory and practice of SVRG", O. Sebbouh, S. Jelassi, N. Gazagnadou, F. Bach, R. M. Gower (2019)

## --- EXPERIMENT 2.B ---
Goal: Comparing Free-SVRG for different inner loop sizes {n, L_max/mu, m^* = L_max/mu, 2n} for 1-nice sampling.

## --- THINGS TO CHANGE BEFORE RUNNING ---


## --- HOW TO RUN THE CODE ---
To run this experiment, open a terminal, go into the "StochOpt.jl/" repository and run the following command:
>julia repeat_paper_experiments/repeat_theory_practice_SVRG_paper_experiment_2b_free_inner_loop.jl

## --- EXAMPLE OF RUNNING TIME ---
5min for false

## --- SAVED FILES ---

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

@everywhere begin
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
save_path = "$(save_path)exp2b/"
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

## Set smaller number of skipped iteration for more data points
#          m =   n      2n    Lmax/mu   m*
skip_errors = [[8000   8000     200    300],  # 1) ijcnn1_full + scaled + 1e-1
               [7000   8000    6500   7500],  # 2) ijcnn1_full + scaled + 1e-3
               [30000  40000   40000  45000], # 3) YearPredictionMSD_full + scaled + 1e-1
               [60000  40000   30000  20000], # 4) YearPredictionMSD_full + scaled + 1e-3
               [45000  45000   45000  55000], # 5) slice + scaled + 1e-1
               [45000  45000   45000  55000], # 6) slice + scaled + 1e-3
               [4000   4000      4      4],   # 7) real-sim + unscaled + 1e-1
               [7000   7000     200    200]]  # 8) real-sim + unscaled + 1e-3

@time begin
@sync @distributed for idx_prob in problems
    data = datasets[idx_prob]
    scaling = scalings[idx_prob]
    lambda = lambdas[idx_prob]
    skip_error = skip_errors[idx_prob]
    println("EXPERIMENT : ", idx_prob, " over ", length(problems))
    @printf "Inputs: %s + %s + %1.1e \n" data scaling lambda

    Random.seed!(1)

    if idx_prob == 5 || idx_prob == 6
        global max_epochs = 100
    end

    ## Loading the data
    println("--- Loading data ---")
    data_path = "$(path)data/"
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

    m_star = round(Int64, (3*Lmax)/mu) # theoretical optimal inner loop size for Free-SVRG with 1-nice sampling

    ## List of mini-batch sizes
    numinneriters_list   = [n, 2*n, round(Int64, Lmax/mu), m_star]
    numinneriters_labels = ["n", "2n", "L_{\\max}/\\mu", "3L_{\\max}/\\mu = m^*"]

    ## Running methods
    OUTPUTS = [] # list of saved outputs

    ## Launching Free-SVRG for different mini-batch sizes and m = n
    for idx_numinneriter in 1:length(numinneriters_list)
        ## Monitoring
        numinneriters_label = numinneriters_labels[idx_numinneriter]
        str_numinneriters = @sprintf "%d" numinneriters_list[idx_numinneriter]
        println("\n------------------------------------------------------------")
        println("Current inner loop size: \$m = $numinneriters_label = $str_numinneriters\$")
        println("------------------------------------------------------------")

        numinneriters = numinneriters_list[idx_numinneriter]  # inner loop size set to the number of data points
        options.batchsize = 1                                 # mini-batch size set to 1
        options.stepsize_multiplier = -1.0                    # theoretical step size set in boot_Free_SVRG
        sampling = build_sampling("nice", n, options)
        free = initiate_Free_SVRG(prob, options, sampling, numinneriters=numinneriters, averaged_reference_point=true)

        ## Setting the number of skipped iteration
        options.skip_error_calculation = skip_error[idx_numinneriter] # skip error different for each mini-batch size

        ## Running the minimization
        output = minimizeFunc(prob, free, options)

        output.name = latexstring("\$$numinneriters_label = $str_numinneriters\$")
        OUTPUTS = [OUTPUTS; output]
        println("\n")
    end
    println("\n")

    ## Saving outputs and plots
    if path == "/home/infres/ngazagnadou/StochOpt.jl/"
        suffix = "lame23"
    else
        suffix = ""
    end
    savename = replace(replace(prob.name, r"[\/]" => "-"), "." => "_")
    savename = string(savename, "-exp2b-$(suffix)-$(details)")
    save("$(save_path)outputs/$(savename).jld", "OUTPUTS", OUTPUTS)

    legendpos = :topright
    legendtitle = "Inner loop size m"
    pyplot()
    # plot_outputs_Plots(OUTPUTS, prob, options, suffix="-exp2b-$(suffix)-$(details)", path=save_path, legendpos=legendpos, legendfont=8)
    plot_outputs_Plots(OUTPUTS, prob, options, suffix="-exp2b-$(suffix)-$(details)", path=save_path, legendpos=legendpos, legendtitle=legendtitle, legendfont=9)

end
end

println("\n\n--- EXPERIMENT 2.B FINISHED ---")