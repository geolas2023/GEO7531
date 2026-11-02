-- =====================================================================
--  GEO7531 - 06 : Traitements raster dans PostGIS
--  Prérequis :
--    raster.rouge et raster.pir importés avec raster2pgsql,
--    même SRID et même taille de tuile (-t), par exemple :
--      raster2pgsql -s 32188 -I -C -M -t 256x256 B4.tif raster.rouge | psql -U postgres -d geo7531
--      raster2pgsql -s 32188 -I -C -M -t 256x256 B5.tif raster.pir   | psql -U postgres -d geo7531
--    raster.mnt (section 7) et vecteur.arrondissements (section 5)
--    pour les exemples raster/vecteur.
--  Exécutez les blocs un à un dans le Query Tool.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. Exploration
-- ---------------------------------------------------------------------
SELECT r_table_schema, r_table_name, srid, scale_x, scale_y,
       num_bands, pixel_types, nodata_values
FROM raster_columns
ORDER BY 1, 2;

SELECT rid, (ST_Metadata(rast)).* FROM raster.rouge LIMIT 1;
SELECT (ST_BandMetadata(rast, 1)).* FROM raster.rouge LIMIT 1;
SELECT (ST_SummaryStatsAgg(rast, 1, true)).* FROM raster.rouge;

-- ---------------------------------------------------------------------
-- B. Combiner rouge + PIR dans un raster à 2 bandes
--    bande 1 = rouge, bande 2 = PIR
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS travaux.rouge_pir;

CREATE TABLE travaux.rouge_pir AS
SELECT r.rid,
       ST_AddBand(r.rast, p.rast, 1) AS rast
FROM raster.rouge AS r
JOIN raster.pir   AS p
  ON  ST_UpperLeftX(r.rast) = ST_UpperLeftX(p.rast)
  AND ST_UpperLeftY(r.rast) = ST_UpperLeftY(p.rast);

ALTER TABLE travaux.rouge_pir ADD PRIMARY KEY (rid);
CREATE INDEX rouge_pir_rast_gist ON travaux.rouge_pir USING gist (ST_ConvexHull(rast));
SELECT AddRasterConstraints('travaux', 'rouge_pir', 'rast');

SELECT ST_NumBands(rast) AS nb_bandes FROM travaux.rouge_pir LIMIT 1;  -- attendu : 2

-- ---------------------------------------------------------------------
-- C. NDVI = (PIR - Rouge) / (PIR + Rouge)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS travaux.ndvi;

CREATE TABLE travaux.ndvi AS
SELECT rid,
       ST_MapAlgebra(
           rast, 1,     -- [rast1] = rouge
           rast, 2,     -- [rast2] = PIR
           'CASE WHEN [rast2.val] + [rast1.val] = 0 THEN NULL
                 ELSE ([rast2.val]::float - [rast1.val]) / ([rast2.val]::float + [rast1.val])
            END',
           '32BF'
       ) AS rast
FROM travaux.rouge_pir;

ALTER TABLE travaux.ndvi ADD PRIMARY KEY (rid);
CREATE INDEX ndvi_rast_gist ON travaux.ndvi USING gist (ST_ConvexHull(rast));
SELECT AddRasterConstraints('travaux', 'ndvi', 'rast');

-- Contrôle : les valeurs doivent être comprises entre -1 et 1
SELECT (ST_SummaryStatsAgg(rast, 1, true)).* FROM travaux.ndvi;

-- ---------------------------------------------------------------------
-- D. Raster x vecteur (même SRID obligatoire)
-- ---------------------------------------------------------------------

-- Altitude sous chaque station
SELECT s.nom, ST_Value(m.rast, 1, s.geom) AS altitude
FROM vecteur.stations s
JOIN raster.mnt m ON ST_Intersects(m.rast, s.geom);

-- Statistiques zonales par arrondissement
SELECT nom, (stats).count, round((stats).mean::numeric, 1) AS moyenne,
       (stats).min, (stats).max
FROM (
    SELECT a.nom,
           ST_SummaryStatsAgg(ST_Clip(m.rast, a.geom), 1, true) AS stats
    FROM vecteur.arrondissements a
    JOIN raster.mnt m ON ST_Intersects(m.rast, a.geom)
    GROUP BY a.nom
) AS t
ORDER BY nom;

-- Découpage du MNT selon un arrondissement
DROP TABLE IF EXISTS travaux.mnt_decoupe;
CREATE TABLE travaux.mnt_decoupe AS
SELECT m.rid, ST_Clip(m.rast, a.geom, true) AS rast
FROM raster.mnt m
JOIN vecteur.arrondissements a ON ST_Intersects(m.rast, a.geom)
WHERE a.nom = 'Le Plateau-Mont-Royal';
