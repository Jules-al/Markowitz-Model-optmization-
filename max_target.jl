using JuMP
using Gurobi    

mean_returns = [0.12, 0.15, 0.10, 0.07]
cov_matrix = [0.1 -0.02  0.03  0.07;
        -0.02 0.12 0.04 0.02;
        0.03  0.04 0.15 0.05;
        0.01 0.02 0.05 0.1]

risk_allow = 4.20529801e-02

n_assets = length(mean_returns)

m = Model(Gurobi.Optimizer)
@variable(m, x[1:n_assets]>=0)
#les deux contraintes pour l'optimisation (minimoisation de la variance )
@constraint(m, sum(x)==1)#somme des azctifs 
@constraint(m, sum(x[i]*x[j]*cov_matrix[i,j] for i in 1:n_assets, j in 1:n_assets)<=risk_allow)#rendement attendu 

#objectif d'optimisation 
@objective(m, Max, sum(x[i]*mean_returns[i] for i in 1:n_assets))
optimize!(m)

#Affiche des résultats 
println("Allocation optimale du porte feuille ")
for i in 1: n_assets 
    println("Actis$i :  $(value(x[i]))")
end 

println("Rendement du portefeuille ;: $(objective_value(m))")