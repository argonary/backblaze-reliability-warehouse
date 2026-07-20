{% macro normalize_model(column_name) %}
    -- Canonicalize a Backblaze model string. Backblaze labels the same physical
    -- Western Digital drive inconsistently, both as "WDC WUH721816ALE6L4" and as
    -- bare "WUH721816ALE6L4"; its own published tables omit the "WDC " corporate
    -- prefix. Stripping that redundant prefix collapses the two labels into one
    -- model so the drive is not split across two rows in dim_model / any mart.
    -- Applied in dim_drive and dim_model so the fix lives once, upstream of every
    -- model built on these dimensions. Other model strings pass through unchanged;
    -- manufacturer parsing still resolves (the WD family codes WUH/WDS remain in
    -- the seed).
    case
        when {{ column_name }} like 'WDC %'
            then substr({{ column_name }}, 5)
        else {{ column_name }}
    end
{% endmacro %}
