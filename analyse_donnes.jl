using YFinance 
using DataFrames
using StatsPlots
using Plots
using StatsBase


#données de l'EURO Stoxx 50 / les 30 meilleurs compossants : 
#data = get_prices.(["CA.PA","CAP.PA","ACA.PA","ORA.PA","ML.PA","VIE.PA","MC.PA","RI.PA","SGO.PA", "KER.PA","ATO.PA","WLN.PA","UG.PA","BN.PA","ENGI.PA", "AIR.PA","FP.PA"],range="1y",interval="1d",startdt="2022-01-01", enddt="2022-12-31");

#Données secteur Technologie/ Santé et chimmie/ FINANCE/ TELECOMS /AERONAUTIQUE/ Industrie Lourde / Service et distribution 
#data = get_prices.(["AAPL","MSFT","INTC","ORCL","IBM","HPQ","SNY","NVS","PFE","MRK","DIM.PA","JNJ","ERF.PA","AGNC","BSBK","CVCY","FNLC", "SCOBX","ORA.PA", "VZ", "VOD.L", "DTE.DE","BA","AIR.PA", "BDRAF", "GD", "LMT", "004560.KS", "ALO.PA", "SU.PA", "DG.PA", "BOUYF", "AMZN", "EBAY", "DANOY", "ALO.PA", "MC.PA", "CDI.PA"],range="6mo",interval="1d",startdt="2020-01-01", enddt="2020-06-30");

#EURO STOXX 50
#Données secteur Technologie/ Santé et chimmie/ FINANCE/ TELECOMS /AERONAUTIQUE/ Industrie Lourde / Service et distribution 
data = get_prices.(["AMS","SAP","ASML.AS","CAP.PA","IFX.BE","SNY","NVS","AZN","FRE.DE","BAYN.DE","LLD.DE","ALV.DE","SAN","BNP.PA","GLE.PA","DTE","TEF","ORA.PA","NOKIA.HE","VOD.L","AIR.PA", "SAF.PA","HO.PA", "LDO.MI","DSY.PA", "SIE.BE", "SU.PA","DG.PA","ATLCY", "TTE.PA", "OR.PA", "PG", "NESN.SW", "BN.PA", "ABI.BR"],range="6mo",interval="1d", startdt="2020-01-01", enddt="2020-06-30");
#print(data)

df = vcat([DataFrame(i) for i in data]...)
df[!, "Rendement"] .= (df[!, "close"] .- df[!, "open"]) ./ df[!, "open"]
#println(df)

# Obtenir la liste des tickers uniques
tickers_uniques = unique(df[:, "ticker"])

rendement_or = zeros(Float64, 114, length(tickers_uniques))
println(length(rendement_or))
# Boucle sur les tickers
for (i, tic) in enumerate(tickers_uniques)
    df_tic = filter(row -> row.ticker == tic, df)
    end_index = min(size(df_tic, 1), 114)
    rendement_or[:, i] .= df_tic[1:end_index, "Rendement"]
end

#reation table analyse de donné entreprises / rendements / Kurtosis/skweness
result_table = DataFrame(
    Ticker = String[],
    Rendement = Float64[],
    Kurtosis = Float64[],
    Skewness = Float64[]
)

for tic in tickers_uniques
    df_tic = filter(row -> row.ticker == tic, df)
    
    # Limiter à 114 lignes
    end_index = min(size(df_tic, 1), 114)
    rendement = df_tic[1:end_index, "Rendement"]
    
    # Calculer le kurtosis et le skewness
    kurt = kurtosis(rendement)
    skew = skewness(rendement)
    
    push!(result_table, (Ticker = tic, Rendement = mean(rendement), Kurtosis = kurt, Skewness = skew))
end

# Afficher le tableau résultant
println(result_table)

# Créer un box plot(Boites à moiustaches ) par entreprise
plt1 = plot()  
for tic in unique(df[!,"ticker"])
    df_ticker = filter(row -> row.ticker == tic, df)
    boxplot!(plt1, df_ticker.Rendement, label=tic)
end

# Étiquettes et titre
xlabel!(plt1, "Entreprises")
ylabel!(plt1, "Rendement")
title!(plt1, "Boîte à moustaches par entreprise")

# Ajout les noms d'entreprise en bas de chaque boîte
tick_positions = 1:length(unique(df[!,"ticker"]))
tick_labels = unique(df[!,"ticker"])  
xticks!(plt1, tick_positions, tick_labels, rotation = 90)

# Désactiver les légendes
plot!(plt1, legend=false)

# Afficher le graphique
display(plt1)

secteur_tickers = Dict(
    "Technologie" => ["AMS", "SAP", "ASML.AS", "CAP.PA", "IFX.BE"],
    "Santé et chimie" => ["SNY", "NVS", "AZN", "FRE.DE", "BAYN.DE"],
    "Finance" => ["LLD.DE","ALV.DE", "BBVA.DE","BNP.PA", "GLE.PA"],
    "Télécoms" => ["TEF", "NOKIA.HE", "VOD.L", "ORA.PA", "DTE.DE"],
    "Aéronautique" => ["AIR.PA", "SAF.PA", "HO.PA","LDO.MI", "DSY.PA"],
    "Industrie Lourde" => ["SIE.BE", "SU.PA", "DG.PA", "ATLCY", "TTE.PA"],
    "Service et distribution" => ["OR.PA", "PG", "NESN.SW", "ABI.BR","BN.PA"]
)

# Créer un dictionnaire pour stocker les rendements par secteur
secteur_rendements = Dict{String, Vector{Float64}}()

# Boucle sur les secteurs
for (secteur, tickers) in secteur_tickers
    rendements_secteur = Float64[]
    
    # Boucle sur les tickers du secteur
    for tic in tickers
        if tic in tickers_uniques
            rendements_secteur = vcat(rendements_secteur, vec(rendement_or[:, findall(x -> x == tic, tickers_uniques)]))
        end
    end
    
    # Stocker les rendements du secteur dans le dictionnaire
    secteur_rendements[secteur] = rendements_secteur
end

# Créer un tableau avec les rendements par secteur
rendements_par_secteur = [secteur_rendements[secteur] for secteur in keys(secteur_rendements)]

# Tracer les boxplots avec la bibliothèque Plots
plt2 = plot()
for (i, secteur) in enumerate(keys(secteur_rendements))
    boxplot!(plt2, rendements_par_secteur[i], label=secteur)
end

# Personnaliser le graphique
xlabel!(plt2, "Secteur")
ylabel!(plt2, "Rendement")
title!(plt2, "Boxplots par Secteur")

# Utiliser xticks! pour spécifier les étiquettes et la rotation
positions = 1:length(keys(secteur_rendements))
label = keys(secteur_rendements)

plot!(plt2 , legend=:outerright)

# Afficher le graphique
display(plt2)

# Créer un box plot(Boites à moiustaches ) par entreprise pour le secteur finacier 
plt1 = plot()  
for tic in tickers_uniques[31:35]
    df_ticker = filter(row -> row.ticker == tic, df)
    boxplot!(plt1, df_ticker.Rendement, label=tic)
end

# Étiquettes et titre
xlabel!(plt1, "Entreprises")
ylabel!(plt1, "Rendement")
title!(plt1, "Boîte à moustaches par entreprise, secteur service et biens de consommation")

# Ajout les noms d'entreprise en bas de chaque boîte
tick_positions = 1:5 #1:length(unique(df[!,"ticker"]))
tick_labels = tickers_uniques[31:35] 
xticks!(plt1, tick_positions, tick_labels, rotation = 90)

# Désactiver les légendes
plot!(plt1, legend=false)

# Afficher le graphique
display(plt1)


plot()
# boucle sur lmes tickers 
rendement = zeros(Float64, 114, length(tickers_uniques))
for (i,tic) in enumerate(tickers_uniques)
    df_tic = filter(row -> row.ticker == tic, df)
    
    # Limiter à 114 lignes
    end_index = min(size(df_tic, 1), 114)
    rendement[:,i] .= df_tic[1:end_index, "Rendement"]
   
    
    # Plot histogram
    histogram(rendement, bins=50, label=tic, alpha=0.7)
end

# Display all histograms
plot!(legend=:topright, xlabel="Returns", ylabel="Frequency", title="Histogram of Returns")


rendement_moy = zeros(Float64,length(tickers_uniques))
for i in 1:length(tickers_uniques)
    rendement_moy[i]=mean(rendement_or[:, i])
end  
#tracé des histogrammes entreprises 
plt = plot(legend=:outerright, label="rendement_moy")
plt = bar(tickers_uniques[1:5],rendement_moy[1:5], label ="rendement_moy",xlabel="Entreprises",ylabel="Rendements moyens", legend=:outerright, rotation=90)
title!(plt,"Rendement moyen des entreprises secteur Technologie ")

display(plt)

"""
#Tracer du graphique des rendement
plt = plot()

#Ajouter les lignes pour chaque entreprise avec des couleurs différentes
for tic in unique(df[!, "ticker"])
    df_tic = filter(row -> row.ticker == tic, df)
    plot!(plt,df_tic.timestamp, df_tic.Rendement, label=tic, linewidth=2)
end

#Ajout les étiquettes et titre
xlabel!(plt,"Jours")
ylabel!(plt,"Rendement")
title!(plt,"Rendement des entreprises")

#Desactiver les legendes
plot!(plt, legend=:outerright, legendcolumns=2)

# Afficher le graphique
display(plt)

"""
"""
#Tracé de l'evolution des valeurs à la femetures dans deux panneaux 
plt =plot()
#Ajouter les lignes pour chaque entreprise avec des couleurs différentes
for tic in unique(df[!, "ticker"])
    df_tic = filter(row -> row.ticker == tic, df)
    plot!(plt,df_tic.timestamp, df_tic.close, label=tic, linewidth=2)
end
#Ajout les étiquettes et titre
xlabel!(plt,"Jours")
ylabel!(plt,"Close value")
title!(plt,"Close value des entreprises")


plot!(plt, legend=:outerright, legendcolumns=2)

# Afficher le graphique
display(plt)



"""
"""

"""
