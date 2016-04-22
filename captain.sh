#!/bin/bash

kraken="kraken"
bootstrap_commits=(cf46fb13afe66ba475db9725e9269c9c1cd3bbc3 2cd43e5a217318c70097334b3598d2924f64b362)

if [[ $1 == "clean" ]]
then
    rm ${kraken}
    rm ${kraken}_bac
    rm ${kraken}_deprecated
    rm ${kraken}_bootstrap
    rm -rf bootstrap_kalypso
else
    if [[ $1 == "backup" ]]
    then
        rm ${kraken}
    fi
    if [[ $1 == "from_old" ]]
    then
        rm ${kraken}
        rm ${kraken}_bac
        rm ${kraken}_deprecated
    fi
    if [[ $1 == "rebuild" ]]
    then
        rm ${kraken}
        rm ${kraken}_bac
        rm ${kraken}_deprecated
        rm ${kraken}_bootstrap
        rm -rf bootstrap_kalypso
    fi

    if [ -s "$kraken" ]
    then
        #echo "$kraken exists, calling"
        ./${kraken} ${kraken}.krak ${kraken}
    else
        echo "gotta make $kraken, testing for compilers to do so"
        if ! [ -s "${kraken}_bac" ]
        then
            if ! [ -s "${kraken}_deprecated" ]
            then
                echo "no ${kraken}_deprecated, bootstrapping using kraken_bootstrap"
                if ! [ -s "${kraken}_bootstrap" ]
                then
                    echo "no ${kraken}_bootstrap, bootstrapping using Cephelpod and a chain of old Kalypsos"
                    git clone . bootstrap_kalypso
                    pushd bootstrap_kalypso
                    git checkout ${bootstrap_commits[0]}
                    cp -r stdlib deprecated_compiler
                    cp krakenGrammer.kgm deprecated_compiler
                    cp kraken.krak deprecated_compiler
                    pushd deprecated_compiler
                    mkdir build
                    pushd build
                    cmake ..
                    make
                    popd
                    mkdir build_kraken
                    mv kraken.krak build_kraken
                    pushd build_kraken
                    ../build/kraken kraken.krak
                    popd
                    popd
                    pushd deprecated_compiler/build_kraken/kraken
                    sh kraken.sh
                    popd
                    cp deprecated_compiler/build_kraken/kraken/kraken ./${kraken}_bootstrap
                    # loop through the chain
                    for ((i=1; i < ${#bootstrap_commits[@]}; i++))
                    do
                        echo "building kalypso bootstrap part $i"
                        echo "commit hash: ${bootstrap_commits[$i]}"
                        mv ./krakenGrammer.kgm krakenGrammer.kgm_old
                        git checkout ${bootstrap_commits[$i]}
                        mv ./krakenGrammer.kgm krakenGrammer.kgm_new
                        mv ./krakenGrammer.kgm_old krakenGrammer.kgm
                        ./${kraken}_bootstrap kraken.krak ${kraken}_bootstrap
                        mv ./krakenGrammer.kgm_new krakenGrammer.kgm
                    done
                    popd # out of bootstrap
                fi
                echo "making kraken_deprecated - the first current Kraken version, but built with an old compiler"
            
                # Now make real
                mv ./krakenGrammer.kgm krakenGrammer.kgm_new
                mv ./krakenGrammer.kgm.comp_new krakenGrammer.kgm.comp_new_new
                cp bootstrap_kalypso/krakenGrammer.kgm ./
                cp bootstrap_kalypso/krakenGrammer.kgm.comp_new ./
                cp bootstrap_kalypso/${kraken}_bootstrap ./${kraken}_bootstrap
                ./${kraken}_bootstrap kraken.krak ${kraken}_deprecated
                mv ./krakenGrammer.kgm_new krakenGrammer.kgm
                mv ./krakenGrammer.kgm.comp_new_new krakenGrammer.kgm.comp_new
            else
                echo "${kraken}_deprecated exists, calling"
            fi
            echo "making kraken_bac, a current compiler built with kraken_deprecated"
            ./${kraken}_deprecated kraken.krak ${kraken}_bac
        else
            echo "${kraken}_bac exists, calling"
        fi
        echo "making kraken, the real current compiler built with kraken_bac"
        ./${kraken}_bac kraken.krak ${kraken}
    fi
fi

#./${kraken} $@


