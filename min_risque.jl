using Gurobi    
using YFinance 
using DataFrames
using StatsPlots
using Plots
using Statistics
using LinearAlgebra
using JuMP


 
# #Données secteur Technologie/ Santé et chimmie/ FINANCE/ TELECOMS /AERONAUTIQUE/ Industrie Lourde / Service et distribution 
#data = get_prices.(["AAPL","MSFT","INTC","ORCL","IBM","HPQ","SNY","NVS","PFE","MRK","DIM.PA","JNJ","ERF.PA","AGNC","BSBK","CVCY","FNLC", "SCOBX","ORA.PA", "VZ", "VOD.L", "DTE.DE","BA","AIR.PA", "BDRAF", "GD", "LMT", "004560.KS", "ALO.PA", "SU.PA", "DG.PA", "BOUYF", "AMZN", "EBAY", "DANOY", "ALO.PA", "MC.PA", "CDI.PA"],range="6mo",interval="1d",startdt="2020-01-01", enddt="2020-06-30");
data = get_prices.(["AMS","SAP","ASML.AS","CAP.PA","IFX.BE","SNY","NVS","AZN","FRE.DE","BAYN.DE","LLD.DE","ALV.DE","SAN","BNP.PA","GLE.PA","DTE","TEF","ORA.PA","NOKIA.HE","VOD.L","AIR.PA", "SAF.PA","HO.PA", "LDO.MI","DSY.PA", "SIE.BE", "SU.PA","DG.PA","ATLCY", "TTE.PA", "OR.PA", "PG", "NESN.SW", "BN.PA", "ABI.BR"],range="6mo",interval="1d", startdt="2020-01-01", enddt="2020-06-30");

#Données du CAC 40 / les 30 meilleurs compossants 
#data = get_prices.(["CA.PA","CAP.PA","ACA.PA","ORA.PA","ML.PA","VIE.PA","MC.PA","RI.PA","SGO.PA", "KER.PA","ATO.PA","WLN.PA","UG.PA","BN.PA","ENGI.PA", "AIR.PA","FP.PA"],range="1y",interval="1d",startdt="2022-01-01", enddt="2022-12-31");
df = vcat([DataFrame(i) for i in data]...)
df[!, "Rendement"] .= (df[!, "close"] .- df[!, "open"]) ./ df[!, "open"]
#println(df)
#dictionnaire des secteurs 
secteur_tickers = Dict(
    "Technologie" => ["AMS", "SAP", "ASML.AS", "CAP.PA", "IFX.BE"],
    "Santé et chimie" => ["SNY", "NVS", "AZN", "FRE.DE", "BAYN.DE"],
    "Finance" => ["LLD.DE","ALV.DE", "BBVA.DE","BNP.PA", "GLE.PA"],
    "Télécoms" => ["TEF", "NOKIA.HE", "VOD.L", "ORA.PA", "DTE.DE"],
    "Aéronautique" => ["AIR.PA", "SAF.PA", "HO.PA","LDO.MI", "DSY.PA"],
    "Industrie Lourde" => ["SIE.BE", "SU.PA", "DG.PA", "ATLCY", "TTE.PA"],
    "Service et distribution" => ["OR.PA", "PG", "NESN.SW", "ABI.BR","BN.PA"]
)
# Calcul de ma matrice des covariances 
#------------------------------------------------

# Obtenir la liste des tickers uniques
tickers_uniques = unique(df[:, "ticker"])

# Initialiser une matrice pour stocker les rendements
rendement_or = zeros(Float64, 114, length(tickers_uniques))

for (i, tic) in enumerate(tickers_uniques)
    df_tic = filter(row -> row.ticker == tic, df)
    end_index = min(size(df_tic, 1), 114)
    rendement_or[:,i] = df_tic[1:end_index, "Rendement"]
end
#Calculer de la matrice dde covariance 

cov_matrix = cov(rendement_or)

#println(cov_matrix)

#Considerons la rendement moyen sur la periode considérée 
println(length(tickers_uniques))
rendement_moy = zeros(Float64,length(tickers_uniques))
for i in 1:length(tickers_uniques)
    rendement_moy[i]=mean(rendement_or[:, i])
end 
println(rendement_moy)
mean_returns = rendement_moy

target_return =mean(rendement_moy)#rendement souhaité 
#target_return=0.4105143751617762 
target_return= 0.38862265150741815/2
println(target_return)
n_assets = length(tickers_uniques)

m = Model(Gurobi.Optimizer)
@variable(m, x[1:n_assets]>=0)
#les deux contraintes pour l'optimisation (minimoisation de la variance )
@constraint(m, sum(x)==1)#somme des azctifs 
@constraint(m, dot(mean_returns,x)>= target_return)#rendement attendu 

#Ajout de la contrainte de diversification pour différents secteurs  
secteurs =keys(secteur_tickers)
println(secteurs)

print(df[1, "ticker"])
#objectif d'optimisation 
#@objective(m, Min, 0.5*sum(x[i]*x[j]*cov_matrix[i,j] for i in 1:n_assets, j in 1:n_assets))
@objective(m, Min, 0.5*dot(x, cov_matrix * x))
optimize!(m)

#Affiche des résultats 

#APrès obtention, effectuons un traitement des x afin de rendre les résultats plus réalisables 

# Après l'optimisation et l'obtention des valeurs x

x_fin = zeros(Float64,length(x))
for i in 1:n_assets 
    allocation = round(value(x[i]), digits=6) # Arrondir à 6 chiffres après la virgule
    if allocation < 0.0001 # seuil d'un actif dans le portefeuille pratique
        allocation = 0.000000
    end
    #println(tickers_uniques[i],": ", allocation)
    x_fin[i]= allocation
end 

# Ajuste les allocations après avoir mis les petites allocations à zéro
total_allocation = sum(x_fin) # Calcule la somme des allocations après ajustement
if total_allocation != 1.0 # Vérifie si la somme est différente de 1
    for i in 1:n_assets
        if x_fin[i] != 0.0 # Ajuste seulement les allocations non nulles
            x_fin[i] = x_fin[i] / total_allocation # VérifieNormalise les résultats 
        end
    end
end
total_allocation = sum(x_fin)
println(total_allocation)
global secteur_allocation = Dict{String, Float64}()
println("Allocation portefeuille")
for i in 1:n_assets
    println(tickers_uniques[i],": ", round(x_fin[i], digits=6))
    for(sector, tickers) in secteur_tickers
        if tickers_uniques[i] in tickers
            current_allocation = get(secteur_allocation, sector, 0.0)
            global secteur_allocation[sector] =current_allocation+x_fin[i]
            break
        end
    end
end
#Calcul rendement effectif du portefeuille
rendement_effectif_portefeuille = dot(rendement_moy, x_fin)
println("Le rique minimal : $(objective_value(m))")
println("Pour un rendement souhaité de : $target_return")
println("Rendement effectif du portefeuille: $rendement_effectif_portefeuille")
# affiche des pourcentages 
println("\nPourcentages de secteur :")
for (sector, percentage) in secteur_allocation
    println("$sector: $(round(percentage * 100, digits=2))%")
end
print("\n")
default(size=(800, 400))
#hISTOGRAMME VALEURS DES ALLOCATIONS 
bar(value.(x_fin), bar_width=0.7, legend=false, xrotation=90)

# Obtenir le nombre de barres pour définir les positions des étiquettes
nb_bars = length(x)

# Définir les étiquettes de l'axe des x maximumpour qu'elles soient au centre des intervalles
# Les positions seront à 0.5, 1.5, 2.5, etc.
xtick_positions = [i for i in 1:nb_bars]
xticks!(xtick_positions, tickers_uniques)


# Définir les étiquettes et le titre du graphique
xlabel!("Assets")
ylabel!("Allocation actifs")
title!("Portefeuille optimale")

# Affichage du graphique avec la taille définie
plot!(size=(800, 400))

# Create a pie chart
plt = pie(x_fin, labels=tickers_uniques, title="Portefeuille optimal pour un risque de $(round(objective_value(m), digits=6)), \net un rendement de $(round(target_return, digits=4))\n\n\n", legend=false)

# Calcul des positions des étiquettes
angles_cumsum = cumsum([0; x_fin])
angles = angles_cumsum[1:end-1] .+ x_fin ./ 2
radii = 1.1 # Définit le rayon où les étiquettes doivent être placées, légèrement à l'extérieur du camembert

# Ajout des annotations
for (i, angle) in enumerate(angles)
    if x_fin[i] > 0 # Vérifie si la proportion est non nulle
        x_pos = radii * cos(angle * 2 * π)
        y_pos = radii * sin(angle * 2 * π)
        annotate!(plt, [(x_pos, y_pos, text(tickers_uniques[i], 8, :center, :center))])
    end
end

# Display the pie chart
display(plt)
"""
# Créer une série de rendements attendus pour la frontière efficiente
target_returns_efficient = range(minimum(rendement_moy), maximum(rendement_moy), length=60)

# Initialiser les tableaux pour stocker les résultats de la frontière efficiente
efficient_variances = zeros(Float64, length(target_returns_efficient))
efficient_allocations = zeros(Float64, n_assets, length(target_returns_efficient))

# Boucle sur les rendements attendus pour calculer les allocations de la frontière efficiente
for (i, target_return_efficient) in enumerate(target_returns_efficient)
    
    # Créer une nouvelle instance du modèle pour chaque itération
    m_efficient = Model(Gurobi.Optimizer)
    @variable(m_efficient, x[1:n_assets] >= 0)
    @constraint(m_efficient, sum(x) == 1)
    @constraint(m_efficient, dot(mean_returns, x) >= target_return_efficient)
    @objective(m_efficient, Min, 0.5 * dot(x, cov_matrix * x))

    # Résoudre le modèle
    optimize!(m_efficient)

    # Enregistrer les résultats de la frontière efficiente
    efficient_variances[i] = objective_value(m_efficient)
    efficient_allocations[:, i] = value.(x)

end

# Tracé de la frontière efficiente
plot(efficient_variances, target_returns_efficient, label="Frontière Efficient", linewidth=3)

# Tracé des allocations de la frontière efficiente
scatter!(efficient_variances, target_returns_efficient, label="Allocations Efficientes", markersize=4)

# Tracé des allocations du portefeuille optimal
scatter!([objective_value(m)], [target_return], label="Portefeuille Optimal", markersize=8, color=:red)

# Ajouter des étiquettes et un titre au graphique
xlabel!("Risque (Variance)")
ylabel!("Rendement attendu")
title!("Frontière Efficient avec Portefeuille Optimal")

# Affichage du graphique avec la taille définie
plot!(size=(800, 400))

"""

"""
#Ajout de la contrainte de diversification pour différents secteurs  
secteurs =keys(secteur_tickers)
println(secteurs)

for sector in secteurs
    tickers = secteur_tickers[sector]
    @constraint(m, sum(x[i] for i in 1:n_assets if tickers_uniques[i] in tickers) >= 0.05)
end
print(df[1, "ticker"])
"""



"""for sector in secteurs
    tickers = secteur_tickers[sector]
    @constraint(m, sum(x[i] for i in 1:n_assets if tickers_uniques[i] in tickers) >= 0.05)
end"""