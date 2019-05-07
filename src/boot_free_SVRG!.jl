"""
    initiate_free_SVRG(prob, options ; numinneriters=0, averaged_reference_point=false)

Initiate the Free-SVRG method for b-nice sampling.
It uniformly picks b data points out of n at each iteration to build an estimate of the gradient.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
- **Int64** numinneriters: size of the inner loop (theoretical value m^* if set to -1, number of data samples n if set to 0)
- **Array{Float64}** probs: probability of selecting each coordinate (used for independent sampling)
- **Bool** averaged_reference_point: select if the reference point is an average of the iterates of the inner loop or the last one
# OUTPUTS
- **free\\_SVRG\\_method** method: Free-SVRG mini-batch method for b-nice sampling
"""
function initiate_free_SVRG(prob::Prob, options::MyOptions, sampling::AbstractString ; numinneriters::Int64=0, averaged_reference_point::Bool=false, probs::Array{Float64}=Float64[])
    n = prob.numdata
    batchsize = options.batchsize

    epocsperiter = batchsize/n
    gradsperiter = batchsize

    name = "Free-SVRG"
    if sampling == "independent" # independent sampling
        if isempty(probs) || length(probs) != n
            error("Uncorrect probabilities")
        else
            if all(y->y==probs[1], probs) ## check if the probabilities are uniform
                b = round(Int64, sum(probs)) ## estimate of the average cardinal of the mini-batch
                name = string(name, "-", b)
            end
            name = string(name, "-indep")
        end
    elseif sampling == "nice" # b-nice sampling
        if batchsize > 1
            name = string(name, "-", batchsize)
        end
        name = string(name, "-nice")
    else
        error("Unknown sampling procedure")
    end

    stepmethod = descent_free_SVRG!
    bootmethod = boot_free_SVRG!
    reset = reset_free_SVRG!

    stepsize = 0.0

    L = prob.L
    Lmax = prob.Lmax
    mu = prob.mu

    expected_smoothness = ((n-b)/(b*(n-1)))*Lmax + ((n*(b-1))/(b*(n-1)))*L
    expected_residual = ((n-b)/(b*(n-1)))*Lmax

    if numinneriters == 0
        numinneriters = n
    elseif numinneriters == -1
        numinneriters = floor(Int, (expected_smoothness + 2*expected_residual) / mu) # theoretical optimal value
    end
    reference_point = zeros(prob.numfeatures)
    new_reference_point = zeros(prob.numfeatures)
    reference_grad = zeros(prob.numfeatures)
    if averaged_reference_point
        averaging_weights = zeros(numinneriters)
    else
        averaging_weights = []
    end

    method = free_SVRG_method(epocsperiter, gradsperiter, name, stepmethod, bootmethod, batchsize, stepsize, probs, L, Lmax, mu, expected_smoothness, expected_residual, numinneriters, reference_point, new_reference_point, reference_grad, averaging_weights, reset)

    return method
end


"""
    boot_free_SVRG!(prob, method, options)

Modify the method to set the stepsize based on the smoothness constants of the problem stored in **free\\_SVRG\\_method** and possibly sets the number of skipped error calculation if not specfied such that 30 points are to be plotted.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **free\\_SVRG\\_method** method: Free-SVRG nice method created by `initiate_free_SVRG`
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
# OUTPUTS
- **NONE**
"""
function boot_free_SVRG!(prob::Prob, method::free_SVRG_method, options::MyOptions)
    if options.stepsize_multiplier > 0.0
        println("Manually set step size")
        method.stepsize = options.stepsize_multiplier
    elseif options.stepsize_multiplier == -1.0
        println("Automatically set Free-SVRG step size")
        method.stepsize = 1/(2*(method.expected_smoothness + 2*method.expected_residual))
        options.stepsize_multiplier = method.stepsize # /!\ Modifies the options
        println("Theoretical step size: ", method.stepsize)
    else
        error("Invalid options.stepsize_multiplier")
    end

    if !isempty(method.averaging_weights)
        averaging_weights = [(1-method.stepsize*method.mu)^(method.numinneriters-1-t) for t in 0:(method.numinneriters-1)]
        method.averaging_weights = averaging_weights ./ sum(averaging_weights)
    end
    println("Averaging weights")
    println(method.averaging_weights)

    # WARNING: The following if statement does not seem to modify the method that is returned afterwards...
    if options.skip_error_calculation == 0.0
        options.skip_error_calculation = ceil(options.max_epocs*prob.numdata/(options.batchsize*30)) # show 30 points between 0 and the max number of epochs
        # 20 points over options.max_epocs when there are options.max_epocs *prob.numdata/(options.batchsize)) iterates in total
    end
    println("Skipping ", options.skip_error_calculation, " iterations per epoch\n")
end


"""
    reset_free_SVRG(prob, method, options)

Reset the Free-SVRG method with b-nice sampling, especially the step size, the point and gradient reference.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **free\\_SVRG\\_method**: Free-SVRG mini-batch method for b-nice sampling
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
# OUTPUTS
- **NONE**
"""
function reset_free_SVRG!(prob::Prob, method::free_SVRG_method, options::MyOptions)
    println("\n---- RESET FREE-SVRG ----\n")

    method.batchsize = options.batchsize
    method.stepsize = options.stepsize_multiplier

    method.reference_point = zeros(prob.numfeatures)
    method.reference_grad = zeros(prob.numfeatures)
    method.averaging_weights = []
end