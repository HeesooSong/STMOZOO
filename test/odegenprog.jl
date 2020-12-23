@testset "ODEGenProg" begin

    using STMOZOO.ODEGenProg
    grammar, S = define_grammar()
     
    @testset "odegenprog" begin

    x = 4
    y = 4
    s = foo_bar(x,y)
    @test s == 8

    g = ExprOptimization.GeneticProgram(250,50,5,0.3,0.3,0.4) #I switched to using the build in GP with my custom fitness functions from the ExprOptimization package because it's very fast. 
    results_gp = ExprOptimization.optimize(g, grammar, :R, fitness_test)
    @test results_gp.expr == :(exp(x))

    end

end