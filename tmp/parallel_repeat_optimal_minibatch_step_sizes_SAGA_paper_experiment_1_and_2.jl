### EXPERIMENT 1 & 2

## Computing the upper-bounds of the expected smoothness constant (exp. 1)
## and our step sizes (exp. 2) in parallel.
## In computes all the bounds and step sizes. It is very long (around h on my computer 8 CPUs)

using Distributed

addprocs(3)

@everywhere begin # this part will be available on all CPUs
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
    using LaTeXStrings

    # include("../src/StochOpt.jl") # Be carefull about the path here
end

# @everywhere include("../src/StochOpt.jl")

function include_everywhere(filepath)
    fullpath = joinpath(@__DIR__, filepath)
    @sync for p in procs()
        @async remotecall_wait(include, p, fullpath)
    end
end

include_everywhere("../src/StochOpt.jl")
# include("../src/StochOpt.jl")

## Manual inputs
# include("../src/StochOpt.jl") # Be carefull about the path here
default_path = "./data/";

# datasets = ["gauss-50-24-0.0_seed-1"
#             "diagints-24-0.0-100_seed-1"
#             "diagalone-24-0.0-100_seed-1"
#             "diagints-24-0.0-100-rotated_seed-1"
#             "diagalone-24-0.0-100-rotated_seed-1"
#             "slice"
#             "YearPredictionMSD_full"
#             "covtype_binary"
#             "rcv1_full"
#             "news20_binary"
#             "real-sim"
#             "ijcnn1_full"]

datasets = ["covtype_binary"
            "rcv1_full"
            "news20_binary"
            "real-sim"
            "ijcnn1_full"]

scalings = ["none" "column-scaling"] #for all datasets except real-sim, news20.binary and rcv1

lambdas = [10^(-3) 10^(-1)];

runnb = 1;
@distributed for data in datasets
    for lambda in lambdas
    # @distributed for lambda in lambdas
        if !(data in ["real-sim" "news20.binary" "rcv1"])
            scalings = ["none" "column-scaling"];
        else
            scalings = ["none"];
        end

        for scaling in scalings
        # @distributed for scaling in scalings
            println("\n\n######################################################################")
            println("Run ", string(runnb), " over 42");
            println("Dataset: ", data);
            println(@sprintf "lambda: %1.0e" lambda);
            println("scaling: ", scaling);
            println("######################################################################\n")

            ### LOADING DATA ###
            println("--- Loading data ---");
            ## Only loading datasets, no data generation
            # X, y = loadDataset(default_path, data);

            ### SETTING UP THE PROBLEM ###
            # println("\n--- Setting up the selected problem ---");
            # options = set_options(tol=10.0^(-1), max_iter=10^8, max_time=10.0^2, max_epocs=10^8,
            #                     #   regularizor_parameter = "1/num_data", # fixes lambda
            #                       regularizor_parameter = "normalized",
            #                     #   regularizor_parameter = "Lbar/n",
            #                     #   repeat_stepsize_calculation=true, # used in minimizeFunc_grid_stepsize
            #                       initial_point="zeros", # is fixed not to add more randomness
            #                       force_continue=false); # force continue if diverging or if tolerance reached
            # u = unique(y);
            # if length(u) < 2
            #     error("Wrong number of possible outputs")
            # elseif length(u) == 2
            #     println("Binary output detected: the problem is set to logistic regression")
            #     prob = load_logistic_from_matrices(X, y, data, options, lambda=lambda, scaling=scaling);
            # else
            #     println("More than three modalities in the outputs: the problem is set to ridge regression")
            #     prob = load_ridge_regression(X, y, data, options, lambda=lambda, scaling=scaling);
            # end

            # n = prob.numdata;
            # d = prob.numfeatures;

            # ### COMPUTING THE SMOOTHNESS CONSTANTS ###
            # # Compute the smoothness constants L, L_max, \cL, \bar{L}
            # datathreshold = 24; # if n is too large we do not compute the exact expected smoothness constant nor its relative quantities

            # ########################### EMPIRICAL UPPER BOUNDS OF THE EXPECTED SMOOTHNESS CONSTANT ###########################
            # ### COMPUTING THE BOUNDS ###
            # expsmoothcst = nothing;
            # simplebound, bernsteinbound, heuristicbound, expsmoothcst = get_expected_smoothness_bounds(prob); # WARNING : markers are missing!

            # ### PLOTTING ###
            # println("\n--- Plotting upper bounds ---");
            # pyplot()
            # plot_expected_smoothness_bounds(prob, simplebound, bernsteinbound, heuristicbound, expsmoothcst, showlegend=false);

            # # heuristic equals true expected smoothness constant for tau=1 and n as expected, else it is above as hoped
            # if(n<=datathreshold)
            #     println("Heuristic - expected smoothness gap: ", heuristicbound - expsmoothcst)
            #     println("Simple - heuristic gap: ", simplebound - heuristicbound)
            #     println("Bernstein - simple gap: ", bernsteinbound - simplebound)
            # end
            # ##################################################################################################################


            # ##################################### EMPIRICAL UPPER BOUNDS OF THE STEPSIZES ####################################
            # ### COMPUTING THE UPPER-BOUNDS OF THE STEPSIZES ###
            # simplestepsize, bernsteinstepsize, heuristicstepsize, hofmannstepsize, expsmoothstepsize = get_stepsize_bounds(prob, simplebound, bernsteinbound, heuristicbound, expsmoothcst);

            # ### PLOTTING ###
            # println("\n--- Plotting stepsizes ---");
            # # PROBLEM: there is still a problem of ticking non integer on the xaxis
            # pyplot()
            # plot_stepsize_bounds(prob, simplestepsize, bernsteinstepsize, heuristicstepsize, hofmannstepsize, expsmoothstepsize, showlegend=false);
            # ##################################################################################################################

            # ########################################### SAVNG RESULTS ########################################################
            # save_SAGA_nice_constants(prob, data, simplebound, bernsteinbound, heuristicbound, expsmoothcst,
            #                          simplestepsize, bernsteinstepsize, heuristicstepsize, expsmoothstepsize);
            # ##################################################################################################################
            global runnb += 1;
        end
    end
end

println("\n--- EXPERIMENTS 1 AND 2 FINISHED ---");
