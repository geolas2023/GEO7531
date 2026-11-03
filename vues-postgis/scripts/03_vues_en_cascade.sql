-- =====================================================================
--  GEO7531 - Vues 03 : Construire une analyse par étapes (vues de vues)
--  Section 4 du tutoriel
--
--  Question : quels quartiers ont le plus d'homicides par habitant ?
--  On découpe le problème en petites vues, chacune simple à vérifier.
-- =====================================================================

-- Étape 1 : nombre d'homicides par quartier (zéros compris)
CREATE OR REPLACE VIEW atelier.v_homicides_quartier AS
SELECT q.id,
       count(h.id) AS nb_homicides
FROM atelier.quartiers AS q
LEFT JOIN atelier.homicides AS h
  ON ST_Contains(q.geom, h.geom)
GROUP BY q.id;

-- Étape 2 : on combine avec la vue de densité (section 3) : une vue
-- s'utilise dans une autre vue exactement comme une table
CREATE OR REPLACE VIEW atelier.v_taux_homicides AS
SELECT d.id,
       d.name,
       d.boroname,
       d.population,
       h.nb_homicides,
       round(1000.0 * h.nb_homicides / NULLIF(d.population, 0), 2) AS taux_1000_hab,
       d.geom
FROM atelier.v_densite_quartiers AS d
JOIN atelier.v_homicides_quartier AS h USING (id)
WHERE d.population > 1000;   -- écarter parcs et aéroports presque inhabités

-- Étape 3 : classement à l'intérieur de chaque arrondissement
CREATE OR REPLACE VIEW atelier.v_classement_taux AS
SELECT name,
       boroname,
       taux_1000_hab,
       rank() OVER (PARTITION BY boroname ORDER BY taux_1000_hab DESC) AS rang
FROM atelier.v_taux_homicides;


-- Utilisation : le quartier le plus touché de chaque arrondissement
SELECT * FROM atelier.v_classement_taux WHERE rang = 1;

-- Ajoutez atelier.v_taux_homicides dans QGIS (clé : id) et faites une
-- symbologie graduée sur taux_1000_hab : la carte se met à jour seule
-- si les tables changent.

-- Chaque vue reste utilisable seule, ce qui facilite la vérification :
SELECT sum(nb_homicides) FROM atelier.v_homicides_quartier;   -- presque 3 984
