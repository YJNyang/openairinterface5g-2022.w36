#!/bin/bash

set -euo pipefail

PREFIX=/opt/oai-enb
RRC_INACTIVITY_THRESHOLD=${RRC_INACTIVITY_THRESHOLD:-0}
ENABLE_MEASUREMENT_REPORTS=${ENABLE_MEASUREMENT_REPORTS:-no}
ENABLE_X2=${ENABLE_X2:-no}
THREAD_PARALLEL_CONFIG=${THREAD_PARALLEL_CONFIG:-PARALLEL_SINGLE_THREAD}

# Based another env var, pick one template to use
if [[ -v USE_FDD_CU ]]; then cp $PREFIX/etc/cu.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_FDD_DU ]]; then cp $PREFIX/etc/du.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_FDD_MONO ]]; then cp $PREFIX/etc/enb.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_TDD_MONO ]]; then cp $PREFIX/etc/enb.tdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_FDD_FAPI_RCC ]]; then cp $PREFIX/etc/rcc.nfapi.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_FDD_IF4P5_RCC ]]; then cp $PREFIX/etc/rcc.if4p5.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_TDD_IF4P5_RCC ]]; then cp $PREFIX/etc/rcc.if4p5.tdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_FDD_RRU ]]; then cp $PREFIX/etc/rru.fdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_TDD_RRU ]]; then cp $PREFIX/etc/rru.tdd.conf $PREFIX/etc/enb.conf; fi
if [[ -v USE_NFAPI_VNF ]]; then cp $PREFIX/etc/enb.nfapi.vnf.conf $PREFIX/etc/enb.conf; fi
# Sometimes, the templates are not enough. We mount a conf file on $PREFIX/etc. It can be a template itself.
if [[ -v USE_VOLUMED_CONF ]]; then cp $PREFIX/etc/mounted.conf $PREFIX/etc/enb.conf; fi

# Only this template will be manipulated
CONFIG_FILES=`ls $PREFIX/etc/enb.conf || true`

for c in ${CONFIG_FILES}; do
    # Sometimes templates have no pattern to be replaced.
    if ! grep -oP '@[a-zA-Z0-9_]+@' ${c}; then
        echo "Configuration is already set"
        break
    fi

    # grep variable names (format: ${VAR}) from template to be rendered
    VARS=$(grep -oP '@[a-zA-Z0-9_]+@' ${c} | sort | uniq | xargs)

    # create sed expressions for substituting each occurrence of ${VAR}
    # with the value of the environment variable "VAR"
    EXPRESSIONS=""
    for v in ${VARS}; do
        NEW_VAR=`echo $v | sed -e "s#@##g"`
        if [[ "${!NEW_VAR}x" == "x" ]]; then
            echo "Error: Environment variable '${NEW_VAR}' is not set." \
                "Config file '$(basename $c)' requires all of $VARS."
            exit 1
        fi
        EXPRESSIONS="${EXPRESSIONS};s|${v}|${!NEW_VAR}|g"
    done
    EXPRESSIONS="${EXPRESSIONS#';'}"

    # render template and inline replace config file
    sed -i "${EXPRESSIONS}" ${c}

    echo "=================================="
    echo "== Configuration file: ${c}"
    cat ${c}
done

# Load the USRP binaries
echo "=================================="
echo "== Load USRP binaries"
if [[ -v USE_B2XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t b2xx
elif [[ -v USE_X3XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t x3xx
elif [[ -v USE_N3XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t n3xx
fi

# enable printing of stack traces on assert
export gdbStacks=1

echo "=================================="
echo "== Starting eNB soft modem"
if [[ -v USE_ADDITIONAL_OPTIONS ]]; then
    echo "Additional option(s): ${USE_ADDITIONAL_OPTIONS}"
    new_args=()
    while [[ $# -gt 0 ]]; do
        new_args+=("$1")
        shift
    done
    for word in ${USE_ADDITIONAL_OPTIONS}; do
        new_args+=("$word")
    done
    echo "${new_args[@]}"
    exec "${new_args[@]}"
else
    echo "$@"
    exec "$@"
fi
