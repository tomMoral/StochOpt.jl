# Front end for plotting the execution in time and in flops of the outputs recorded in OUTPUTS.
function plot_outputs_Plots(OUTPUTS,prob::Prob, options, datapassbnd::Int64) #, datapassbnd::Int64
  #Now in epocs X function values
  probname= string(replace(prob.name, r"[\/]", "-"),"-",options.batchsize);
  if(options.precondition)
    probname= string(probname,"-precon")
  end
   default_path = "./data/";  # savename= string(replace(prob.name, r"[\/]", "-"),"-", options.batchsize);
  save("$(default_path)$(probname).jld", "OUTPUTS",OUTPUTS);
  fontsmll = 8;
  fontmed = 14;
  fontbig = 14;
# plotting epocs per iteration
  output = OUTPUTS[1];
  rel_loss =(output.fs.-prob.fsol)./(output.fs[1].-prob.fsol);
  fs = output.fs[rel_loss.>0];
  lf = length(fs);
  bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
  plot(output.epocsperiter*(1:bnd)*(output.iterations/lf),(fs[1:bnd].-prob.fsol)./(fs[1].-prob.fsol), xlabel = "iterations",  ylabel = "subopt", yscale = :log10, label  = output.name,
  linestyle=:auto,  tickfont=font(fontsmll), guidefont=font(fontbig), legendfont =font(fontmed), markersize = 6, linewidth =4, marker =:auto,  grid = false)
  for j =2:length(OUTPUTS)
    output = OUTPUTS[j];
    rel_loss =(output.fs.-prob.fsol)./(output.fs[1].-prob.fsol);
    fs = output.fs[rel_loss.>0];
    lf = length(fs);
    bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
    plot!(output.epocsperiter*(1:bnd)*(output.iterations/lf),(fs[1:bnd].-prob.fsol)./(fs[1].-prob.fsol), xlabel = "iterations",  ylabel = "subopt", yscale = :log10, label  = output.name,
    linestyle=:auto,  tickfont=font(fontsmll), guidefont=font(fontbig), legendfont =font(fontmed), markersize = 6, linewidth =4, marker =:auto,  grid = false)
  end
  println("./figures/$(probname)-epoc.pdf")
  savefig("./figures/$(probname)-epoc.pdf");


  # plotting times
  output = OUTPUTS[1];
  rel_loss =(output.fs.-prob.fsol)./(output.fs[1].-prob.fsol);
  fs = output.fs[rel_loss.>0];
  lf = length(fs);
  bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
  plot(output.times[1:bnd],(fs[1:bnd].-prob.fsol)./(fs[1].-prob.fsol), xlabel = "time", ylabel = "subopt", yscale = :log10, label  = output.name, linestyle=:auto,  tickfont=font(fontsmll), guidefont=font(fontbig), legendfont =font(fontmed),  markersize = 6, linewidth =4, marker =:auto,  grid = false)
  println(output.name,": 2^", log(2,output.stepsize_multiplier))
  for jiter =2:length(OUTPUTS)
    output = OUTPUTS[jiter];
    rel_loss =(output.fs.-prob.fsol)./(output.fs[1].-prob.fsol);
    fs = output.fs[rel_loss.>0];
    lf = length(fs);
    bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
    plot!(output.times[1:bnd],(fs[1:bnd].-prob.fsol)./(fs[1].-prob.fsol), xlabel = "time", ylabel = "subopt", yscale = :log10, label  = output.name, linestyle=:auto,  tickfont=font(fontsmll), guidefont=font(fontbig), legendfont =font(fontmed),  markersize = 6, linewidth =4, marker =:auto,  grid = false)
    println(output.name,": 2^", log(2,output.stepsize_multiplier))
  end
  println(probname)
  savefig("./figures/$(probname)-time.pdf");

  open("./figures/$(probname)-stepsizes.txt", "w") do f
    write(f, "$(probname) stepsize_multiplier \n")
    for i =1:length(OUTPUTS)
      output = OUTPUTS[i];
      loofstep = log(2,output.stepsize_multiplier);
      outname = output.name;
      write(f, "$(outname) : 2^ $(loofstep)\n")
    end
  end
end


# plotting gradient computations per iteration
# output = OUTPUTS[1];
# lf = length(output.fs);
# bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
# plot(output.gradsperiter*(1:bnd)*(output.iterations/lf),(output.fs[1:bnd].-prob.fsol)./(output.fs[1].-prob.fsol),
# xlabel = "grads",
# ylabel = "subopt",
# yscale = :log10,
# label  = output.name,
# linestyle=:auto,   tickfont=font(12), guidefont=font(18), legendfont =font(12),  markersize = 8, linewidth =4,
# marker =:auto,  grid = false)
# println(output.name,": 2^", log(2,output.stepsize_multiplier))
# for jiter =2:length(OUTPUTS)
#   output = OUTPUTS[jiter];
#   lf = length(output.fs);
#   bnd = convert(Int64,min(ceil(datapassbnd*lf/(output.iterations*output.epocsperiter)),lf));
#   plot!(output.gradsperiter*(1:bnd)*(output.iterations/lf),(output.fs[1:bnd].-prob.fsol)./(output.fs[1].-prob.fsol), yscale = :log10,
#   label  = output.name, linestyle=:auto, marker =:auto, grid = false, markersize = 8, linewidth =4)
#   println(output.name,": 2^", log(2,output.stepsize_multiplier))
# end
# println(probname)
# savefig("./figures/$(probname)-grads.pdf");
