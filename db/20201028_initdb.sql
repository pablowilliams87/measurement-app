CREATE DATABASE environment_airq_measurand;

CREATE TABLE environment_airq_measurand (
    id_environment_airq_measurand SERIAL PRIMARY KEY,
    timestamp TIMESTAMP,
    id_entity VARCHAR(50),
    so2 FLOAT8,
    no2 FLOAT8,
    co FLOAT8,
    o3 FLOAT8,
    pm10 FLOAT8,
    pm2_5 FLOAT8
);

/*
COMMENT ON COLUMN environment_airq_measurand.timestamp IS 'measures are taken every 15'
COMMENT ON COLUMN environment_airq_measurand.id_entity IS 'quality air station identifier'
COMMENT ON COLUMN environment_airq_measurand.so2 IS 'μg/m3 of SO2 (Sulfur dioxide)'
COMMENT ON COLUMN environment_airq_measurand.no2 IS 'μg/m3 of NO2 (Nitrogen dioxide)'
COMMENT ON COLUMN environment_airq_measurand.co IS 'mg/m3 of CO (Carbon monoxide)'
COMMENT ON COLUMN environment_airq_measurand.o3 IS 'μg/m3 of O3 (Ozone)'
COMMENT ON COLUMN environment_airq_measurand.pm10 IS 'μg/m3 of PM10 (particulate matter with 10 μm or less in diameter)'
COMMENT ON COLUMN environment_airq_measurand.pm2_5 IS 'μg/m3 of PM2,5 (particulate matter with 2,5 μm or less in diameter)'
*/
