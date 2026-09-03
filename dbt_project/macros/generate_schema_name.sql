{#
    デフォルトの dbt 挙動 (<target_schema>_<custom_schema_name>) ではなく、
    models/ 配下の +schema 設定 (silver / gold) をそのままスキーマ名として使う。
    Databricks 版の silver_/gold_ カタログレイヤー構成に合わせるための上書き。
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
