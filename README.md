# desjardins-modele-attribution-maison
Code R présenté par [Sébastien Brodeur](https://www.linkedin.com/in/brodseba/) de chez Desjardins lors du [DAMM](https://www.linkedin.com/groups/3745656/) de juin 2019.  Ce code permet de rouler une requête BigQuery afin d'identifier l'attribution en filtrant pour ne conserver dans notre modèle que les visites significatives.  Le script R utilise ensuite le package [channelAttribution](https://cran.r-project.org/web/packages/ChannelAttribution/index.html) pour mesurer le résultat en utilisant un modèle de chaîne de Markov (le même modèle utilisé par le modèle data-driven dans Google Analytics.)

## Architecture de la solution
![Architecture de la solution](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/Attribution-Maison.png)

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
