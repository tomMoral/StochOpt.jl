using JLD
using Plots
using StatsBase
using Match
using Combinatorics
using Random # julia 0.7
using Printf # julia 0.7
using LinearAlgebra # julia 0.7
using Statistics # julia 0.7
using Base64 # julia 0.7

include("../src/StochOpt.jl") # Be carefull about the path here

default_path = "./data/";

Random.seed!(1);

### LOADING DATA ###
println("--- Loading data ---");
datasets = readlines("$(default_path)available_datasets.txt");

## Only loading datasets, no data generation
idx = 4; # australian
data = datasets[idx];

@time X, y = loadDataset(data);

# varinfo(r"(X|y|prob)")

### SETTING UP THE PROBLEM ###
println("\n--- Setting up the selected problem ---");
options = set_options(tol=10.0^(-1), max_iter=10^8, max_time=10.0^2, max_epocs=10^8,
                    #   regularizor_parameter = "1/num_data", # fixes lambda
                      regularizor_parameter = "normalized",
                    #   regularizor_parameter = "Lbar/n",
                      initial_point="zeros", # is fixed not to add more randomness 
                      force_continue=false); # force continue if diverging or if tolerance reached

@time prob = load_logistic_from_matrices(X, y, data, options, lambda=-1, scaling="none");  # scaling = centering and scaling

# # varinfo(r"(X|y|prob)")

X = nothing; # available in prob.X
y = nothing; # available in prob.y
# # varinfo(r"(X|y|prob)")

############################################# australian #############################################
#region
## Computing the solution with a serial gridsearch
# @time get_fsol_logistic!(prob)
## 0.49591251564486827  /   100 000 epochs  /  beststep = 2^7.0
## 0.3378005242384954   / 1 000 000 epochs  /  beststep = 2^7.0

options = set_options(tol=10.0^(-16.0), skip_error_calculation=10^5, exacterror=false, max_iter=10^8, 
                      max_time=60.0*60.0*3.0, max_epocs=10^7, force_continue=true);
## Running BFGS
options.stepsize_multiplier = 2^(7.0); # beststep = 2^(7.0) for batchsize = prob.numdata

options.batchsize = prob.numdata;
method_input = "BFGS";
output = minimizeFunc(prob, method_input, options);

## Saving the optimization output in a JLD file
a, savename = get_saved_stepsize(prob.name, method_input, options);
a = nothing;
save("$(default_path)$(savename).jld", "output", output)

## Setting the true solution as the smallest of both
prob.fsol = minimum(output.fs);
println("\n----------------------------------------------------------------------")
@printf "For %s, fsol = %f\n" prob.name prob.fsol
println("----------------------------------------------------------------------\n")

## Saving the solution in a JLD file
fsolfilename = get_fsol_filename(prob); # not coherent with get_saved_stepsize output
save("$(fsolfilename)_try_2.jld", "fsol", prob.fsol)
#endregion
######################################################################################################