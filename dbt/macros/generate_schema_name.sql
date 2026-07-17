{% macro generate_schema_name(custom_schema_name, node) -%}
    {#- Un schéma par couche (staging/intermediate/marts), sans préfixe du schéma
        cible du profil — cf. commentaire dans snowflake/setup.sql. -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
