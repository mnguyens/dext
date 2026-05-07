{#
    Override dbt's default schema-naming behaviour. By default dbt concatenates
    the profile's target schema with any +schema: set in dbt_project.yml,
    producing names like `raw_staging`, `raw_intermediate`, `raw_marts`.

    We want layered schemas to stand on their own (`staging`, `intermediate`,
    `marts`) while seeds without a custom schema continue to land in the
    profile's target schema (`raw`).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
