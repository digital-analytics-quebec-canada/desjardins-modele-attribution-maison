# desjardins-modele-attribution-maison
[Script R](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/attribution-maison.R) présenté par [Sébastien Brodeur](https://www.linkedin.com/in/brodseba/) de chez Desjardins lors du [DAMM](https://www.linkedin.com/groups/3745656/) de juin 2019.  Ce code permet de rouler une requête BigQuery afin d'identifier l'attribution en filtrant pour ne conserver dans notre modèle que les visites significatives.  Le script R utilise ensuite le package [channelAttribution](https://cran.r-project.org/web/packages/ChannelAttribution/index.html) pour mesurer le résultat en utilisant un modèle de chaîne de Markov (le même modèle utilisé par le modèle data-driven dans Google Analytics.)

## Pourquoi?
La très grande majorité des visiteurs sur notre site viennent pour effectuer leurs transactions financières quotidiennes.  Nous avons donc un fort volume de trafic qui n'est pas significative lorsque nous voulons mesurer l'attribution pour une campagne numérique sur la portion informationnel.
![Multitudes de visites, mais seulement certaines sont pertinentes](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/attribution-maison-pourquoi.png)
Donc, ce modèle maison va éliminer les visites qui ne sont pas pertinentes pour l'analyse dans ce contexte.  Par exemple, nous pourrions conserver uniquement les visites durant lesquelles un compotement de magasinnage à eu lieu (ex. : consultation d'une page produit, utilisation d'un simulateur, consultation des taux, etc.)  Nous allons ensuite appliquer un modèle de chaine de Markov pour mesurer l'attribution.

## Architecture de la solution
![Architecture de la solution](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/Attribution-Maison.png)

### Pré-requis
1. Être client Google Analytics 360. (https://marketingplatform.google.com/about/analytics-360/)
2. Avoir activé l'importation des données Google Analytics dans BigQuery. (https://support.google.com/analytics/answer/3437618?hl=en)

### Fonctionnement
1. Les données de notre compte Google Analytics 360 sont envoyé à chaque jour dans BigQuery.
2. Un script R est exécuter à chaque jour pour chaque conversions que nous voulons attribuer.
3. Le script va sauvegarder les données dans une table BigQuery.
4. À la fin, un tableau de bord Data Studio permet d'analyser les conversions dans le temps.

Voici un exemple d'utilisation de la fonction R. Dans cet exemple, nous tentons d'identifier les canaux responsables de la complétion du formulaire de prise de rendez-vous.
<pre>
// FetchBQData(sourceProjet, sourceDataset, destinationTable, conversionID, conversionSQL, itemsSQL, window)

FetchBQData(
  "projectID",
  "datasetId",
  "modele_attribution_maison_channel",
  "Form-Prise-Rendez-Vous",
  "hits.eventInfo.eventCategory = 'Formulaire' AND hits.eventInfo.eventAction = 'complete' AND hits.eventInfo.eventLabel = 'Prise de rendez-vous'",
  "IF(trafficSource.isTrueDirect, 'Direct', channelGrouping)"
)</pre>

### Exemple de tableau de bord Data Studio qui utilise ces données pour comparer les modèles d'attributions.
![Comparaison des divers modèles](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/attribution-maison-ds-2.png)

![Tableau sommaire des conversions par canaux](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/attribution-maison-ds-1.png)

## Pour vous connecter à BigQuery depuis R, vous devez :
1. Créer un service account (https://cloud.google.com/iam/docs/creating-managing-service-accounts)
2. Donner les droits d'utiliser BigQuery à ce service account. (https://cloud.google.com/iam/docs/granting-changing-revoking-access)
3. Récupérer le service acount token (fichier JSON) (https://cloud.google.com/iam/docs/creating-managing-service-account-keys)
4. Appaler la fonction set_service_token() en indiquant l'emplacement du fichier.

### Considération de sécurité :
1. Assurez-vous que le service account n'a que les accès minimums nécessaire à exécuter la requête BigQuery (bigquery-user) et injecter les données dans une table (bigquery-dataEditor) via la console IAM.
2. Assurez-vous de protéger le fichier JSON (service_account_token.json) car quiconque à ce fichier peut exécuter des requêtes comme s'il avait les même accès que le service acount.
