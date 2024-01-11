using JuMP
using Gurobi    
using YFinance 
using DataFrames
using StatsPlots
using Plots
using Statistics
using LinearAlgebra
using StatsBase

 #Données secteur Technologie/ Santé et chimmie/ FINANCE/ TELECOMS /AERONAUTIQUE/ Industrie Lourde / Service et distribution 
#data = get_prices.(["AAPL","MSFT","INTC","ORCL","IBM","HPQ","SNY","NVS","PFE","MRK","DIM.PA","JNJ","ERF.PA","AGNC","BSBK","CVCY","FNLC", "SCOBX","ORA.PA", "VZ", "VOD.L", "DTE.DE","BA","AIR.PA", "BDRAF", "GD", "LMT", "004560.KS", "ALO.PA", "SU.PA", "DG.PA", "BOUYF", "AMZN", "EBAY", "DANOY", "ALO.PA", "MC.PA", "CDI.PA"],range="6mo",interval="1d",startdt="2020-01-01", enddt="2020-06-30");
data = get_prices.(["AMS","SAP","ASML.AS","CAP.PA","IFX.BE","SNY","NVS","AZN","FRE.DE","BAYN.DE","LLD.DE","ALV.DE","SAN","BNP.PA","GLE.PA","DTE","TEF","ORA.PA","NOKIA.HE","VOD.L","AIR.PA", "SAF.PA","HO.PA", "LDO.MI","DSY.PA", "SIE.BE", "SU.PA","DG.PA","ATLCY", "TTE.PA", "OR.PA", "PG", "NESN.SW", "BN.PA", "ABI.BR"],range="6mo",interval="1d", startdt="2020-01-01", enddt="2020-06-30");
#
#data = get_prices.(["AAPL","MSFT","AMZN"],range="1y",interval="1d",startdt="2020-01-01", enddt="2020-12-31");


#Creation du rendement dans la dataframe 
df = vcat([DataFrame(i) for i in data]...)
df[!, "Rendement"] .= (df[!, "close"] .- df[!, "open"]) ./ df[!, "open"]
#println(df)

# Calcul de ma matrice des covariances

# Obtenir la liste des tickers uniques
tickers_uniques = unique(df[:, "ticker"])

# Initialiser une matrice pour stocker les rendements(114 pour certaines entreprises, et 142 pour d'autres nous avons conservées le min )
rendement_or = zeros(Float64, 114, length(tickers_uniques))

for (i, tic) in enumerate(tickers_uniques)
    df_tic = filter(row -> row.ticker == tic, df)
    end_index = min(size(df_tic, 1), 114)
    rendement_or[:,i] = df_tic[1:end_index, "Rendement"]
end
#Calculer de la matrice dde covariance 
cov_matrix = cov(rendement_or)
secteur_tickers = Dict(
    "Technologie" => ["AMS", "SAP", "ASML.AS", "CAP.PA", "IFX.BE"],
    "Santé et chimie" => ["SNY", "NVS", "AZN", "FRE.DE", "BAYN.DE"],
    "Finance" => ["LLD.DE","ALV.DE", "BBVA.DE","BNP.PA", "GLE.PA"],
    "Télécoms" => ["TEF", "NOKIA.HE", "VOD.L", "ORA.PA", "DTE.DE"],
    "Aéronautique" => ["AIR.PA", "SAF.PA", "HO.PA","LDO.MI", "DSY.PA"],
    "Industrie Lourde" => ["SIE.BE", "SU.PA", "DG.PA", "ATLCY", "TTE.PA"],
    "Service et distribution" => ["OR.PA", "PG", "NESN.SW", "ABI.BR","BN.PA"]
)
#println(cov_matrix)

#Considerons la rendement moyen sur la periode annuelle
println(length(tickers_uniques))
rendement_moy = zeros(Float64,length(tickers_uniques))
for i in 1:length(tickers_uniques)
    rendement_moy[i]=mean(rendement_or[:, i])
end 
println(rendement_moy)

mean_returns = rendement_moy

#Affectation du risque 
#risk_allow = 4.7036986182295326e-5
#risk_allow = 4.7189142688519486e-5
#risk_allow = 4.7248286343574474e-5
#risk_allow= minimum(cov_matrix)/minimum(cov_matrix)
egal_actif = sum(cov_matrix)/length(mean_returns)
println(egal_actif)
#risk_allow = egal_actif
#risk_allow= 0.0007409525356050627
risk_allow= cov_matrix[1,5]
n_assets = length(mean_returns)
m = Model(Gurobi.Optimizer)
#set_optimizer_attribute(m, "NonConvex", 2)
@variable(m, x[1:n_assets]>=0)
#les deux contraintes pour l'optimisation (minimisation de la variance )
@constraint(m, sum(x)==1)#somme des azctifs 
@constraint(m, 0.5*dot(x, cov_matrix*x )<=risk_allow)#rendement attendu 
#@constraint(m, sum(x[i]^2 for i in 1:n_assets) == 1)
#Ajout de la contrainte de diversification pour différents secteurs  
secteurs =keys(secteur_tickers)
println(secteurs)

for sector in secteurs
    tickers = secteur_tickers[sector]
    @constraint(m, sum(x[i] for i in 1:n_assets if tickers_uniques[i] in tickers) >= 0.05)
end
print(df[1, "ticker"])
#objectif d'optimisation 
@objective(m, Max, dot(mean_returns, x))
#@constraint(m, x .>= 0.01)
optimize!(m)
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
total_allocation = sum(x_fin) # Calculer la somme des allocations après ajustement
if total_allocation != 1.0 # Vérifie si la somme est différente de 1
    for i in 1:n_assets
        if x_fin[i] != 0.0 # Ajuste seulement les allocations non nulles
            x_fin[i] = x_fin[i] / total_allocation
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

# Calcul de la variance du portefeuille
variance_effective = 0.5*dot(x_fin, cov_matrix * x_fin)

# Calcul de l'écart-type du portefeuille (racine carrée de la variance)
ecart_type_portefeuille = sqrt(variance_effective)

# Affichage du risque effectif
println("Risque effectif du portefeuille (variance) : $variance_effective")
println("Risque effectif du portefeuille (écart-type) : $ecart_type_portefeuille")
println("Le rendement maximal : $(objective_value(m))")
println("Pour un risque souhaité de : $risk_allow")
# affiche des pourcentages 
println("\nPourcentages de secteur :")
for (sector, percentage) in secteur_allocation
    println("$sector: $(round(percentage * 100, digits=2))%")
end
bar(value.(x), bar_width=0.7, legend=false, xrotation=90)

# Obtenir le nombre de barres pour définir les positions des étiquettes
nb_bars = length(x)

# Définir les étiquettes de l'axe des x pour qu'elles soient au centre des intervalles
# Les positions seront à 0.5, 1.5, 2.5, etc.
xtick_positions = [i for i in 1:nb_bars]
xticks!(xtick_positions, tickers_uniques)

# Rotation des étiquettes de l'axe des x à 90 degrés pour une meilleure lisibilité
#xrotation!(90)

# Définir les étiquettes et le titre du graphique
xlabel!("Assets")
ylabel!("Allocation actifs")
title!("Portefeuille optimale")

# Affichage du graphique avec la taille définie
plot!(size=(800, 400))

#""""""

# Create a pie chart
plt = pie(x_fin, labels=tickers_uniques, title="Portefeuille optimal pour un rendement de $(round(objective_value(m), digits=6)), \net un risque de $(round(risk_allow, digits=6))\n\n\n", legend=false)

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
#Ajout de la contrainte de diversification pour différents secteurs  
secteurs =keys(secteur_tickers)
println(secteurs)

for sector in secteurs
    tickers = secteur_tickers[sector]
    @constraint(m, sum(x[i] for i in 1:n_assets if tickers_uniques[i] in tickers) >= 0.07)
end
print(df[1, "ticker"])
"""