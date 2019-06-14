# desjardins-modele-attribution-maison
Code R présenté par Sébastien Brodeur lors du DAMM de juin 2019.  Ce code permet de rouler une requête BigQuery afin d'identifier l'attribution en filtrant pour ne conserver dans notre modèle que les visites significatives.  Le script R utilise ensuite le package channelAttribution pour mesurer le résultat en utilisant un modèle de chaîne de Markov.  Le même modèle utilisé par le modèle data-driven dans Google Analytics.

![Architecture de la solution](https://github.com/digital-analytics-quebec-canada/desjardins-modele-attribution-maison/blob/master/Attribution-Maison.png)
