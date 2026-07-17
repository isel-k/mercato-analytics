-- Bootstrap Snowflake pour Mercato Analytics.
-- A exécuter une seule fois, en tant qu'ACCOUNTADMIN, dans un worksheet
-- Snowsight.
-- Réf. conventions CLAUDE.md : rôles LOADER/TRANSFORMER (moindre privilège),
-- warehouse XS, resource monitor actif, un schéma RAW par source.

use role accountadmin;

-- warehouse -------------------------------------------------------------
create warehouse if not exists mercato_wh
warehouse_size = 'XSMALL'
auto_suspend = 60
auto_resume = true
initially_suspended = true;

-- resource monitor : garde-fou coûts (crédit gratuit du trial est limité) --
-- Note : sqlfluff ne connaît pas la grammaire admin CREATE RESOURCE MONITOR,
-- le lint échoue dessus (faux positif) ; la syntaxe est correcte côté
-- Snowflake.
create resource monitor if not exists mercato_rm
with credit_quota = 10
frequency = monthly
start_timestamp = immediately
triggers
on 75 percent do notify
on 100 percent do suspend
on 110 percent do suspend_immediate;

alter warehouse mercato_wh set resource_monitor = mercato_rm;

-- databases + schémas RAW (un par source, cf. architecture CLAUDE.md) ----
create database if not exists raw;
create database if not exists analytics;

create schema if not exists raw.raw_transfermarkt;
create schema if not exists raw.raw_footballdata;
create schema if not exists raw.raw_fbref;

-- rôles -------------------------------------------------------------------
create role if not exists loader;
create role if not exists transformer;

-- LOADER : écrit uniquement dans RAW (utilisé par dlt) ---------------------
grant usage on warehouse mercato_wh to role loader;
grant usage on database raw to role loader;
grant create schema on database raw to role loader;
-- dlt émet un CREATE SCHEMA IF NOT EXISTS à chaque run (vérif idempotente),
-- même si le schéma existe déjà : il faut donc ce droit au niveau database.
grant usage on all schemas in database raw to role loader;
grant usage on future schemas in database raw to role loader;
grant create table on schema raw.raw_transfermarkt to role loader;
grant create table on schema raw.raw_footballdata to role loader;
grant create table on schema raw.raw_fbref to role loader;
grant all on future tables in schema raw.raw_transfermarkt to role loader;
grant all on future tables in schema raw.raw_footballdata to role loader;
grant all on future tables in schema raw.raw_fbref to role loader;

-- TRANSFORMER : lit RAW, écrit ANALYTICS (utilisé par dbt) -----------------
grant usage on warehouse mercato_wh to role transformer;
grant usage on database raw to role transformer;
grant usage on all schemas in database raw to role transformer;
grant select on all tables in database raw to role transformer;
grant select on future tables in database raw to role transformer;

grant usage on database analytics to role transformer;
grant create schema on database analytics to role transformer;
-- dbt crée lui-même les schémas staging/intermediate/marts au premier run ;
-- l'ownership du schéma créé donne les droits nécessaires dessus.

-- attribution des rôles à ton utilisateur ----------------------------------
-- Remplace <YOUR_USER> par ton nom d'utilisateur Snowflake avant d'exécuter.
grant role loader to user <YOUR_USER>;
grant role transformer to user <YOUR_USER>;
