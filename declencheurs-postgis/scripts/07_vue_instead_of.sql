-- =====================================================================
--  GEO7531 - Déclencheurs 07 : Rendre une vue modifiable (INSTEAD OF)
--  Section 9 du tutoriel
--
--  Une vue présente les stations en longitude / latitude (WGS 84),
--  pratique pour un site Web ou un formulaire. Mais on ne peut pas
--  écrire dans une colonne calculée par ST_Transform : le déclencheur
--  INSTEAD OF dit à PostgreSQL quoi faire « à la place ».
-- =====================================================================

CREATE OR REPLACE VIEW labo.v_stations_wgs84 AS
SELECT id,
       name,
       routes,
       round(ST_X(ST_Transform(geom, 4326))::numeric, 6) AS lon,
       round(ST_Y(ST_Transform(geom, 4326))::numeric, 6) AS lat
FROM labo.stations;

-- Sans déclencheur, cet INSERT échoue :
-- ERREUR: cannot insert into column "lon" of view "v_stations_wgs84"


CREATE OR REPLACE FUNCTION labo.f_v_stations_ecrire()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO labo.stations (name, routes, geom)
    VALUES (NEW.name, NEW.routes,
            ST_Transform(ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326), 26918))
    RETURNING id INTO NEW.id;            -- renvoyer l'id créé à l'appelant
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE labo.stations
    SET name   = NEW.name,
        routes = NEW.routes,
        geom   = ST_Transform(ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326), 26918)
    WHERE id = OLD.id;
    RETURN NEW;

  ELSE  -- DELETE
    DELETE FROM labo.stations WHERE id = OLD.id;
    RETURN OLD;
  END IF;
END;
$$;

CREATE TRIGGER trg_v_stations_ecrire
  INSTEAD OF INSERT OR UPDATE OR DELETE
  ON labo.v_stations_wgs84
  FOR EACH ROW                         -- INSTEAD OF est toujours FOR EACH ROW
  EXECUTE FUNCTION labo.f_v_stations_ecrire();


-- ---------------------------------------------------------------------
-- Essais : on écrit dans la VUE, les données vont dans la TABLE
-- ---------------------------------------------------------------------
INSERT INTO labo.v_stations_wgs84 (name, routes, lon, lat)
VALUES ('Station Hudson Yards (test)', '7', -74.0021, 40.7553)
RETURNING id;

SELECT id, name, ST_AsText(geom, 0)          -- stockée en UTM 18N
FROM labo.stations WHERE name LIKE 'Station Hudson%';

UPDATE labo.v_stations_wgs84
SET lat = lat + 0.001                         -- environ 110 m vers le nord
WHERE name LIKE 'Station Hudson%';

DELETE FROM labo.v_stations_wgs84 WHERE name LIKE 'Station Hudson%';

-- Les déclencheurs de la table (journal, recompte) ont réagi eux aussi :
SELECT operation, apres ->> 'name' AS nom, avant ->> 'name' AS ancien_nom
FROM labo.journal
WHERE coalesce(apres, avant) ->> 'name' LIKE 'Station Hudson%'
ORDER BY id;
