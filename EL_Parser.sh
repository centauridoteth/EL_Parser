#!/bin/bash

# Default values

LOGFILE=""
CLIENT=""
LIMIT=0 # "0" will disable limit on numbers of lines parsed. The whole file will be parsed


# Parse command line arguments

while getopts ":hn:t:c:l:" opt; do
case ${opt} in
h )
echo "Usage: $0 [options]"
echo ""
echo "Options:"
echo "  -h              Help (show this message)"
echo "  -n <limit>      Limit to <limit> lines parsed, potentially useful for VERY large logfiles (default: off) "
echo "  -l <logfile>    Choose the logfile to parse, set it permanently with the LOGFILE variable"
echo "  -c <client>     Choose which client to parse the logs for, set it permanently with the CLIENT variable"
echo "  -t <tps|mgas>   Will return the maximum and average throughput of the client as measured by tps/mgas (default: both) "
exit 0
;;
t )
THROUGHPUT=$OPTARG
;;
n )
LIMIT=$OPTARG
;;
c )
CLIENT=${OPTARG^^}
;;
l )
LOGFILE=$OPTARG
;;
? )
echo "Invalid option: -$OPTARG" 1>&2
exit 1
;;
: )
echo "Invalid option: -$OPTARG requires an argument" 1>&2
exit 1
;;
esac
done

# awk commands to calculate throughput

throughput_mgas_nethermind (){
    awk 'BEGIN {
    max_mgas = 0
    sum_mgas = 0
    count = 0
    }
    /Block throughput/ {
    match($0, /([0-9,\.]+) MGas/)
    mgas_val = substr($0, RSTART, RLENGTH)
    gsub(/[^0-9.]/, "", mgas_val)
    mgas_val += 0

    sum_mgas += mgas_val
    count++
    if (mgas_val > max_mgas) {
        max_mgas = mgas_val
    }
    }
    END {
    if (count > 0) {
        avg_mgas = sum_mgas / count
        print "Average Mgas: " avg_mgas
        print "Max Mgas: " max_mgas
    } else {
        print "No Mgas data found."
    }
    }'
}
throughput_tps_nethermind (){
    awk 'BEGIN {
    max_tps = 0
    sum_tps = 0
    count = 0
    }
    /Block throughput/ {
    match($0, /([0-9,\.]+) tps/)
    tps_val = substr($0, RSTART, RLENGTH)
    gsub(/[^0-9.]/, "", tps_val)
    tps_val += 0

    sum_tps += tps_val
    count++
    if (tps_val > max_tps) {
        max_tps = tps_val
    }
    }
    END {
    if (count > 0) {
        avg_tps = sum_tps / count
        print "Average TPS: " avg_tps
        print "Max TPS: " max_tps
    } else {
        print "No TPS data found."
    }
    }'
}

throughput_mgas_geth (){
    awk 'BEGIN {
    max_mgas = 0
    sum_mgas = 0
    count = 0
    }
    /Imported new potential chain segment/ {
    match($0, /mgasps=([0-9,\.]+)/)
    mgas_val = substr($0, RSTART+7, RLENGTH-7)
    gsub(/[^0-9.]/, "", mgas_val)
    mgas_val += 0
    sum_mgas += mgas_val
    count++
    if (mgas_val > max_mgas) {
        max_mgas = mgas_val
    }
    }
    END {
    if (count > 0) {
        avg_mgas = sum_mgas / count
        print "Average Mgas: " avg_mgas
        print "Max Mgas: " max_mgas
    } else {
        print "No Mgas data found."
    }
    }'
}
throughput_tps_geth (){
    awk 'BEGIN {
    max_tps = 0
    sum_tps = 0
    count = 0
    }
    /Imported new potential chain segment/ {
    # Extract txs value
    match($0, /txs=([0-9]+)/)
    if (RSTART > 0) {
        txs_val = substr($0, RSTART+4, RLENGTH-4)
        txs_val += 0

        # Skip if no transactions
        if (txs_val > 0) {
            # Extract elapsed time
            match($0, /elapsed=([0-9.]+)(ms|s)/)
            if (RSTART > 0) {
                time_str = substr($0, RSTART+8, RLENGTH-8)

                # Check if time is in milliseconds or seconds
                if (match(time_str, /ms$/)) {
                    # Convert milliseconds to seconds
                    gsub(/ms$/, "", time_str)
                    elapsed_seconds = time_str / 1000
                } else {
                    # Already in seconds
                    gsub(/s$/, "", time_str)
                    elapsed_seconds = time_str + 0
                }

                # Calculate TPS
                if (elapsed_seconds > 0) {
                    tps_val = txs_val / elapsed_seconds
                    sum_tps += tps_val
                    count++
                    if (tps_val > max_tps) {
                        max_tps = tps_val
                    }
                }
            }
        }
    }
    }
    END {
    if (count > 0) {
        avg_tps = sum_tps / count
        print "Average TPS: " avg_tps
        print "Max TPS: " max_tps
    } else {
        print "No TPS data found."
    }
    }'
}

throughput_mgas_besu (){
    awk 'BEGIN {
    max_mgas = 0
    sum_mgas = 0
    count = 0
    }
    /Imported #[0-9,]+/ {
    match($0, /([0-9,\.]+) Mgas\/s/)
    if (RSTART > 0) {
        mgas_val = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9.]/, "", mgas_val)
        mgas_val += 0
        sum_mgas += mgas_val
        count++
        if (mgas_val > max_mgas) {
            max_mgas = mgas_val
        }
    }
    }
    END {
    if (count > 0) {
        avg_mgas = sum_mgas / count
        print "Average Mgas: " avg_mgas
        print "Max Mgas: " max_mgas
    } else {
        print "No Mgas data found."
    }
    }'
}
throughput_tps_besu (){
    awk 'BEGIN {
    max_tps = 0
    sum_tps = 0
    count = 0
    }
    /Imported #[0-9,]+/ {
    # Extract txs value
    match($0, /([0-9]+) tx/)
    if (RSTART > 0) {
        txs_val = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", txs_val)
        txs_val += 0

        # Skip if no transactions
        if (txs_val > 0) {
            # Extract elapsed time
            match($0, /([0-9.]+)s exec/)
            if (RSTART > 0) {
                time_str = substr($0, RSTART, RLENGTH)
                gsub(/[^0-9.]/, "", time_str)
                elapsed_seconds = time_str + 0

                # Calculate TPS
                if (elapsed_seconds > 0) {
                    tps_val = txs_val / elapsed_seconds
                    sum_tps += tps_val
                    count++
                    if (tps_val > max_tps) {
                        max_tps = tps_val
                    }
                }
            }
        }
    }
    }
    END {
    if (count > 0) {
        avg_tps = sum_tps / count
        print "Average TPS: " avg_tps
        print "Max TPS: " max_tps
    } else {
        print "No TPS data found."
    }
    }'
}

throughput_mgas_reth (){
    awk 'BEGIN {
    max_mgas = 0
    sum_mgas = 0
    count = 0
    }
    /Block added to canonical chain/ {
    # Look for different gas throughput units
    if (match($0, /gas_throughput.*=.*([0-9.]+) Ggas\/second/)) {
        # Extract Ggas and convert to Mgas
        match($0, /([0-9.]+) Ggas\/second/)
        mgas_val = substr($0, RSTART, RLENGTH)
        gsub(/ Ggas\/second/, "", mgas_val)
        mgas_val = (mgas_val + 0) * 1000  # Convert Ggas to Mgas
    }
    else if (match($0, /gas_throughput.*=.*([0-9.]+) Mgas\/second/)) {
        # Extract Mgas directly
        match($0, /([0-9.]+) Mgas\/second/)
        mgas_val = substr($0, RSTART, RLENGTH)
        gsub(/ Mgas\/second/, "", mgas_val)
        mgas_val += 0
    }
    else if (match($0, /gas_throughput.*=.*([0-9.]+) Kgas\/second/)) {
        # Extract Kgas and convert to Mgas
        match($0, /([0-9.]+) Kgas\/second/)
        mgas_val = substr($0, RSTART, RLENGTH)
        gsub(/ Kgas\/second/, "", mgas_val)
        mgas_val = (mgas_val + 0) / 1000  # Convert Kgas to Mgas
    }
    else {
        next  # Skip if no gas_throughput found
    }

    sum_mgas += mgas_val
    count++
    if (mgas_val > max_mgas) {
        max_mgas = mgas_val
    }
    }
    END {
    if (count > 0) {
        avg_mgas = sum_mgas / count
        print "Average Mgas: " avg_mgas
        print "Max Mgas: " max_mgas
    } else {
        print "No Mgas data found."
    }
    }'
}
throughput_tps_reth (){
    awk 'BEGIN {
    max_tps = 0
    sum_tps = 0
    count = 0
    }
    /Block added to canonical chain/ {
    # Use simpler field-based approach to extract values
    txs_val = 0
    elapsed_seconds = 0

    # Split line into fields and find txs value
    for (i = 1; i <= NF; i++) {
        if ($i ~ /txs/) {
            # Extract number from this field
            if (match($i, /[0-9]+/)) {
                txs_val = substr($i, RSTART, RLENGTH) + 0
            }
        }
        if ($i ~ /elapsed/) {
            # Extract time from this field
            if (match($i, /[0-9.]+[µm]s/)) {
                time_str = substr($i, RSTART, RLENGTH)
                if (time_str ~ /µs$/) {
                    gsub(/µs$/, "", time_str)
                    elapsed_seconds = time_str / 1000000
                } else if (time_str ~ /ms$/) {
                    gsub(/ms$/, "", time_str)
                    elapsed_seconds = time_str / 1000
                }
            }
        }
    }

    # Calculate TPS only if we have both values and txs > 0
    if (txs_val > 0 && elapsed_seconds > 0) {
        tps_val = txs_val / elapsed_seconds
        sum_tps += tps_val
        count++
        if (tps_val > max_tps) {
            max_tps = tps_val
        }
    }
    }
    END {
    if (count > 0) {
        avg_tps = sum_tps / count
        print "Average TPS: " avg_tps
        print "Max TPS: " max_tps
    } else {
        print "No TPS data found."
    }
    }'
}

throughput_mgas_erigon (){
    awk 'BEGIN {
    max_mgas = 0
    sum_mgas = 0
    count = 0
    }
    /Execution.*Executed blocks/ {
    # Extract Mgas/s value from Erigon logs
    # Format: [INFO] [MM-DD|HH:MM:SS.mmm] [N/M Execution] Executed blocks number=XXXXX blk/s=XX.X tx/s=XXXX.X Mgas/s=XXX.X
    if (match($0, /Mgas\/s=([0-9.]+)/)) {
        mgas_val = substr($0, RSTART+7, RLENGTH-7)
        mgas_val += 0

        sum_mgas += mgas_val
        count++
        if (mgas_val > max_mgas) {
            max_mgas = mgas_val
        }
    }
    }
    END {
    if (count > 0) {
        avg_mgas = sum_mgas / count
        print "Average Mgas: " avg_mgas
        print "Max Mgas: " max_mgas
    } else {
        print "No Mgas data found."
    }
    }'
}

throughput_tps_erigon (){
    awk 'BEGIN {
    max_tps = 0
    sum_tps = 0
    count = 0
    }
    /Execution.*Executed blocks/ {
    # Extract tx/s value from Erigon logs
    # Format: [INFO] [MM-DD|HH:MM:SS.mmm] [N/M Execution] Executed blocks number=XXXXX blk/s=XX.X tx/s=XXXX.X Mgas/s=XXX.X
    if (match($0, /tx\/s=([0-9.]+)/)) {
        tps_val = substr($0, RSTART+5, RLENGTH-5)
        tps_val += 0

        sum_tps += tps_val
        count++
        if (tps_val > max_tps) {
            max_tps = tps_val
        }
    }
    }
    END {
    if (count > 0) {
        avg_tps = sum_tps / count
        print "Average TPS: " avg_tps
        print "Max TPS: " max_tps
    } else {
        print "No TPS data found."
    }
    }'
}


if [ -z "$LOGFILE" ]; then
    echo "the LOGFILE variable is empty. Please specify it at the top of the file"
    exit 1
fi

if [ -z "$CLIENT" ]; then
    echo "the CLIENT variable is empty. Please specify it at the top of the file"
    exit 1
fi


if [ "$LIMIT" -eq 0 ]; then
COMMAND="tail -n +0"
else
COMMAND="tail -n $LIMIT"
fi

# Select client-specific functions
case "$CLIENT" in
    "GETH"|"geth")
        TPS_FUNCTION="throughput_tps_geth"
        MGAS_FUNCTION="throughput_mgas_geth"
        ;;
    "NETHERMIND"|"nethermind")
        TPS_FUNCTION="throughput_tps_nethermind"
        MGAS_FUNCTION="throughput_mgas_nethermind"
        ;;
    "BESU"|"besu")
        TPS_FUNCTION="throughput_tps_besu"
        MGAS_FUNCTION="throughput_mgas_besu"
        ;;
    "RETH"|"reth")
        TPS_FUNCTION="throughput_tps_reth"
        MGAS_FUNCTION="throughput_mgas_reth"
        ;;
    "ERIGON"|"erigon")
        TPS_FUNCTION="throughput_tps_erigon"
        MGAS_FUNCTION="throughput_mgas_erigon"
        ;;
    *)
        echo "Error: Unsupported client '$CLIENT'. Supported clients: geth, nethermind, besu, reth, erigon"
        exit 1
        ;;
esac

# Execute based on throughput type
if [ "$THROUGHPUT" = "tps" ]; then
    $COMMAND $LOGFILE | $TPS_FUNCTION
elif [ "$THROUGHPUT" = "mgas" ]; then
    $COMMAND $LOGFILE | $MGAS_FUNCTION
else
    $COMMAND $LOGFILE | $MGAS_FUNCTION
    $COMMAND $LOGFILE | $TPS_FUNCTION
fi
