{% macro generate_schema_name(custom_schema_name, node) -%}
    {#- Un schéma par couche (staging/intermediate/marts). Seul le target `prod`
        obtient le schéma "nu" (staging/intermediate/marts) — c'est le seul lu par
        le dashboard Evidence en production. Tout autre target (dev local, ci) reste
        préfixé par son propre target.schema, pour qu'un `dbt run` local ou une CI
        de PR ne puisse jamais écrire dans les tables qui alimentent le dashboard
        public. -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
