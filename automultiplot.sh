#!/usr/bin/env bash

function gnuplot_gen () {
    filename="$1"
    title="$2"
    input="$3"
    extras="$4"

    sed 's/##FILENAME##/'"${filename}"'/' ${BASE_PATH}/Flash-X/automultiplot-header.gp | \
        sed 's/##TITLE##/'"${title}"'/' | sed '50a\'"${extras}"

    # Autodetect columns in input
    ncols=$(head -n 1 "${input}/plot-data.out" | wc -w)
    ncols=$((ncols - 2))
    if [ ${ncols} -eq 0 ]
    then
        marginlist=('5.0, 5.0, 1.6, 2.6')
    elif [ ${ncols} -eq 1 ]
    then
         marginlist=( \
             '5.0, 19.2, 1.6, 2.6' \
             '17.6, 6.6, 1.6, 2.6')
    elif [ ${ncols} -eq 2 ]
    then
         marginlist=( \
                    '5.0, 22.2333333, 1.6, 2.6' \
             '14.5666667, 12.6666666, 1.6, 2.6' \
             '24.1333333, 3.1, 1.6, 2.6')
    elif [ ${ncols} -eq 3 ]
    then
         marginlist=( \
              '5.0, 24.625, 1.6, 2.6' \
             '12.175, 17.45, 1.6, 2.6' \
             '19.35, 10.275, 1.6, 2.6' \
             '26.525, 3.1, 1.6, 2.6')
    else
        echo "ERROR: No plotting configuration available for ${ncols} columns."
    fi

    for n in $(seq 0 ${ncols})
    do
        if [ ${n} -eq 0 ]
        then
            echo "
set key maxrows 1 at character 27.2, character 11.6 right bottom samplen 1 spacing 2.2 width 1 font ',12'
"
        fi

        if [ ${n} -eq ${ncols} ]
        then
            echo "
set y2tics offset -0.7, 0 autofreq 15
set y2label 'Number of [giga]FP ops' offset -2.2, 0
"
        else
            echo "
unset xlabel
unset ylabel
unset y2tics
unset y2label
"
        fi

        echo "
unset xtics
unset ytics

set margins ${marginlist[${n}]}
set title 'M-${n}' offset 0, -0.9

set y2range [0:flop_count_range]
"
        if [ ${n} -eq 0 ]
        then
            echo "
plot '${input}/perf_counts_ref${n}_0001.out' u (\$1-1):((\$2+\$3)/1e9) w boxes axes x1y2 ls 201 title '\\small{Full}', \
     '' u (\$1-1):(\$2/1e9) w boxes axes x1y2 ls 202 title '\\small{Trunc}'

unset label 1

set ylabel 'Truncation error' offset 3.2, 0
set ytics offset 0.7, 0 autofreq 1e4

set key maxrows 1 at character 16.0, character 11.6 right bottom samplen 1 spacing 2.2 width 1 font ',12'
"
        else
            echo "
plot '${input}/perf_counts_ref${n}_0001.out' u (\$1-1):((\$2+\$3)/1e9) w boxes axes x1y2 ls 201 notitle, \
     '' u (\$1-1):(\$2/1e9) w boxes axes x1y2 ls 202 notitle

set format y ''
set ytics
"
        fi

        if [ ${n} -eq ${ncols} ]
        then
            echo "
unset y2tics
unset y2label
"
        fi

        echo "
unset title
set xtics ('4' 4, '20' 20, '36' 36, '52' 52) offset 0, 0.5
set grid ytics mytics ls 100, ls 101

set y2range [speedup_range_lo:speedup_range_hi]
"
        if [ ${n} -eq 0 ]
        then
            echo "plot '${input}/plot-data.out' u 1:2 w l ls 290 notitle, \\"

            for p in $(seq 3 ${ncols})
            do
                echo "'${input}/plot-data.out' u 1:${p} w l ls 290 notitle, \\"
            done

            echo "'${input}/plot-data.out' u 1:$((n+2)) w l ls 204 title '\\small{L1 Error}'"
        else
            echo "plot '${input}/plot-data.out' u 1:2 w l ls 290 notitle, \\"

            for p in $(seq 3 ${ncols})
            do
                echo "'${input}/plot-data.out' u 1:${p} w l ls 290 notitle, \\"
            done

            echo "'${input}/plot-data.out' u 1:$((n+2)) w l ls 204 notitle"
        fi
    done
}



mkdir -p figures

gnuplot_gen 'sod-bt' 'Sod' 'plots/sod_0001' | gnuplot
gnuplot_gen 'sedov-bt' 'Sedov' 'plots/sedov_0001' | gnuplot
