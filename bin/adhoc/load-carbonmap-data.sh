#!/bin/bash

set -ex

simplification=20000
alternate_simplification=10000
countries_less_simplified="GB CH FR ES AT IT BY UA SK HU RO RS BG SA AE OM IR IQ JP BD IN CN MN LA BT NP MY VN"
simplification_json='{"BE": 5000, "NL": 5000, "LU": 5000, "DE": 5000, "CZ": 5000, "PL": 5000, "QA": 5000}'

all_datasets="Area Population GDP  Extraction Emissions Consumption Historical Reserves  PeopleAtRisk SeaLevel Poverty"

col_Area="Land area (sq. km)"
col_Population='Population, total, 2010'
col_GDP='GDP, PPP (current international $), 2010'

col_Extraction="CO2 from fossil fuels extracted, 2010"
col_Emissions="CO2 from fossil fuel use (million tonnes, 2010)"
col_Consumption="Consumption footprint, million tonnes CO2, 2010"
col_Historical="Cumulative CO2 emissions from energy, 1850–2007 (million tonnes)"
col_Reserves="Potential CO2 from proven reserves (MT)"

col_PeopleAtRisk="Number of people exposed to droughts, floods, extreme temps"
col_SeaLevel="Population below 5m"
col_Poverty='Population living below $1.25 a day'


if [ "$1" = "--regenerate" ]
then
    shift
    regenerate=true
else
    regenerate=false
fi
datasets="${1-${all_datasets}}"


for f in $datasets
do
    if $regenerate
    then
        bin/delete-data.py "carbonmap:$f"
        eval col=\${col_$f}
        bin/load-data.py "carbonmap:$f" kiln-data/Maps/With\ alpha-2/$f.csv countries "Alpha-2" "$col"
        bin/density-grid.py "carbonmap:$f" world-robinson > kiln-data/Maps/Cartogram\ data/"$f".density && \
        cart 1500 750 kiln-data/Maps/Cartogram\ data/"$f".density kiln-data/Maps/Cartogram\ data/"$f".cart
    fi
    bin/as-svg.py --dataset "carbonmap:$f" --cart kiln-data/Maps/Cartogram\ data/"$f".cart --map world-robinson --json --simplification "$simplification" --alternate-simplification "$alternate_simplification" --alternate-simplification-regions "$countries_less_simplified" --simplification-json "$simplification_json" > kiln-data/Maps/Cartogram\ data/$f.json
done

(
    echo "// This file is auto-generated. Please do not edit."
    echo "// Generated at $(date)"
    
    echo 'var carbonmap_data = {};'
    echo 'var carbonmap_values = {};'
    
    echo -n 'carbonmap_data._raw = '
    bin/as-svg.py --map world-robinson --json --simplification "$simplification" --alternate-simplification "$alternate_simplification" --alternate-simplification-regions "$countries_less_simplified" --simplification-json "$simplification_json" | perl -pe 's/$/;/'
    if [ ${PIPESTATUS[0]} -ne 0 ]
    then
        exit ${PIPESTATUS[0]}
    fi
    
    echo -n 'carbonmap_data._raw._text = "'
    markdown_py -o html5 -s escape -e utf-8 kiln-data/Maps/Reset.text.md | perl -l40pe ''
    echo '";'
    
    echo -n 'carbonmap_data._names = '
    bin/csv-to-json --key iso2 --value name data/continents.csv
    echo ';'
    
    for f in $all_datasets
    do
        if [ -e kiln-data/Maps/Cartogram\ data/"$f".json ]
        then
            echo -n "carbonmap_data.$f = "
            perl -pe 's/$/;/' kiln-data/Maps/Cartogram\ data/"$f".json
            
            echo -n "carbonmap_data.$f._text = \""
            markdown_py -o html5 -s escape -e utf-8 kiln-data/Maps/"$f".text.md | perl -l40pe 's/"/\\"/g'
            echo '";'
            
            eval col=\${col_$f}
            echo -n "carbonmap_values.$f = "
            bin/csv-to-json --key Alpha-2 --value "$col" --type=float --format="{:,.1f}" kiln-data/Maps/With\ alpha-2/$f.csv
            echo ';'
        fi
    done
) > kiln-output/data.js

bin/adhoc/dump-project-data.py carbonmap > kiln-data/dumped.csv

set +x
echo
echo "If you need to regenerate the embedded SVG, run:"
echo "  bin/as-svg.py --map world-robinson --simplification \"$simplification\" --alternate-simplification \"$alternate_simplification\" --alternate-simplification-regions \"$countries_less_simplified\" --simplification-json '$simplification_json'"
echo
