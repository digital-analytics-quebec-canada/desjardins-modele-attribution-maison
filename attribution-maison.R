library(dplyr)
library(reshape)
library(lubridate)
library(bigrquery)
library(ChannelAttribution)

# Configuration initiale.
set.seed("12345")

# Indiquer le Google Cloud Project.  C'est ce projet qui sera facturé et aussi le destination pour le résultats du script.
project <- "ga-bigquery-001"

# Le dataset de destination pour le résultats du script.
destinationDataset = "Attribution_Data"

# Pour vous connecter à BigQuery depuis ce script, vous devez :
#  1 - Créer un service account (https://cloud.google.com/iam/docs/creating-managing-service-accounts)
#  2 - Donner les droits d'utiliser BigQuery à ce service account. 
#  3 - Récupérer le service acount token (fichier JSON) (https://cloud.google.com/iam/docs/creating-managing-service-account-keys)
#  4 - Appaler la fonction set_service_token() en indiquant l'emplacement du fichier.

# Considération de sécurité :
#  1 - Assurez-vous que le service account n'a que les accès minimums nécessaire à exécuter la requête BigQuery (bigquery-user) et injecter les données dans une table (bigquery-dataEditor) via la console IAM.
#  2 - Assurez-vous de protéger le fichier JSON (service_account_token.json) car quiconque à ce fichier peut exécuter des requêtes comme s'il avait les même accès que le service acount.
set_service_token("service_account_token.json")

# C'est cette fonction que vous devrez appeler.  Comme vous aurez probablement plusieurs conversions que vous voudrez mesurer.
FetchBQData <- function(destinationTable, conversionID, conversionSQL, itemsSQL = "IF(trafficSource.isTrueDirect, 'Direct', channelGrouping)", window = 30) {
  sql <- sprintf("
    #legacySQL
# ------------- 4 - Bâtir les séquences dans un format utilisable par le package R channelAttribution.  -------------
    SELECT
      sequences,
      COUNT(DISTINCT B.sessionID) AS countConversions,
      SUM(totalSessions) - COUNT(DISTINCT B.sessionID) AS countNoConversions
    FROM (
      SELECT
        B.Date,
        B.sessionID,
        GROUP_CONCAT(A.items, ' > ') AS sequences,
        COUNT(DISTINCT A.sessionID) AS totalSessions
      FROM (
# ------------- 3 - Joindre les 2 tables -------------
        SELECT
          A.*,
          B.*
        FROM (
# ------------- 2 - Identifier les sources de trafic des sessions des 30 derniers jours que nous voulons conserver. -------------
          SELECT
            Date,
            visitStartTime,
            fullVisitorId,
# ------------- 2.1 - Identifier par quel dimension nous souhaitons effectuer l'attribution. -------------
            REPLACE(%s, ' ', '') AS items,  # itemsSQL
            CONCAT(fullVisitorId, STRING(visitId)) AS sessionID
          FROM
            TABLE_DATE_RANGE([ga-bigquery-001:83891127.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -%i, 'DAY'), DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'))  # %i = window
          WHERE
# ------------- 2.2 - Comment voulons-nous filtrer nos visites. -------------
            # Définir les rèlges qui déterminent quel visites conservées pour mesurer l'attribution.
            hits.eCommerceAction.action_type = '2'  # Consultation d'une page produit (enhanced eCommerce : The action type. Click through of product lists = 1, Product detail views = 2, Add product(s) to cart = 3, Remove product(s) from cart = 4, Check out = 5, Completed purchase = 6, Refund of purchase = 7, Checkout options = 8, Unknown = 0.)
            # Mais vous pourriez ajouter une visite sur une page ou section spécifique : 
            OR (hits.page.pagePath = '/page1' OR hits.page.pagePath CONTAINS ('/section/'))
          ) A
          LEFT JOIN (
# ------------- 1 - Identifier les visiteurs qui ont effectué hier la conversion que nous voulons suivre. -------------
            SELECT
              Date,
              fullVisitorId,
              CONCAT(fullVisitorId, STRING(visitId)) AS sessionID
            FROM
              TABLE_DATE_RANGE([ga-bigquery-001:83891127.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'), DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'))
            WHERE
# ------------- 1.1 - Quel action définis une visite avec conversion. -------------
              %s  # %s = conversionSQL
            GROUP BY
              Date,
              fullVisitorId,
              sessionID
          ) B
          ON
            A.fullVisitorId = B.fullVisitorId
          ORDER BY
            A.fullVisitorId,
            A.Date,
            A.visitStartTime
        )
        GROUP BY
          A.Date,
          A.fullVisitorId,
          B.Date,
          B.sessionID
        )
      GROUP BY
        sequences", itemsSQL, window, conversionSQL)

  # Exécuter la requête à BigQuery.
  results <- query_exec(sql, project, useLegacySql = TRUE)

  # Utiliser channelAttribution pour calculer l'attribution.
  H <- heuristic_models(results, var_path="sequences", var_conv="countConversions") # Last click, First Click et Linear
  M <- markov_model(results, var_path="sequences", var_conv="countConversions", var_null="countNoConversions", order=4, max_step=30)  # Chaine de Markov.

  # Joindre le résultats des 2 méthodes dans un même dataFrame.
  models <- merge(H, M, by="channel_name")

  # Renommer les colonnes après la jointure.
  colnames(models) <- c('channel_name', 'First', 'Last', 'Linear', 'Markov')
  
  # Identifier le nom de la conversion.
  models$Conversions <- conversionID

  # Ajouter la date traiter (par défaut hier.)
  models$Date <- today() - 1

  rownames(models) <- NULL
  models$channel_name <- as.character(models$channel_name)

  # Injecter les données dans la table de destination de BigQuery.
  insert_upload_job(project, destinationDataset, destinationTable, models)
}

# Dans cet exemple, nous tentons d'identifier les canaux responsables de la complétion du formulaire de prise de rendez-vous.
FetchBQData("modele_attribution_maison_channel",
  "Form-Prise-Rendez-Vous",
  "hits.eventInfo.eventCategory = 'Formulaire' AND hits.eventInfo.eventAction = 'complete' AND hits.eventInfo.eventLabel = 'Prise de rendez-vous'",
  "IF(trafficSource.isTrueDirect, 'Direct', channelGrouping)"
)

# Dans cet exemple, nous tentons d'identifier les campagnes/canaux responsables de la complétion du formulaire de prise de rendez-vous.
FetchBQData("modele_attribution_maison_campaign", 
  "Form-Prise-Rendez-Vous", 
  "hits.eventInfo.eventCategory = 'Formulaire' AND hits.eventInfo.eventAction = 'complete' AND hits.eventInfo.eventLabel = 'Prise de rendez-vous'", 
  "IF(trafficSource.isTrueDirect, '(not set)', IF(trafficSource.campaign = '(not set)', CONCAT(channelGrouping, '|(not set)'), CONCAT(channelGrouping, '|', trafficSource.campaign)))"
)
