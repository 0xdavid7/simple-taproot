#!/bin/sh
run() {
    NAME=${1:-"bitcoin-regtest"}
    docker run --rm -d \
        --name ${NAME} \
        -p 18332:18332 \
        -p 18333:18333 \
        -v $(pwd)/.bitcoin:/root/.bitcoin \
        -v $(pwd)/bitcoin.conf:/root/.bitcoin/bitcoin.conf \
        -v $(pwd)/bitcoin.sh:/root/bitcoin.sh \
        -e DATADIR=/root/.bitcoin \
        -u root \
        -w /root/.bitcoin \
        --entrypoint /bin/sh \
        lncm/bitcoind:v25.0 /root/bitcoin.sh entrypoint
}

createwallet_descriptors() {
    WALLET_NAME=${1:-user}
    WALLET_PASSPHRASE=${2:-passphrase}

    bitcoin-cli -named createwallet \
        "wallet_name=${WALLET_NAME}" \
        "passphrase=${WALLET_PASSPHRASE}" \
        "load_on_startup=true" \
        "descriptors=true" # Use descriptors for Taproot and P2WPKH addresses

    echo "LISTING WALLETS"
    bitcoin-cli listwallets
}

unlock_wallet() {
    WALLET_NAME=${1:-staker}
    WALLET_PASSPHRASE=${2:-passphrase}
    bitcoin-cli -rpcwallet=${WALLET_NAME} walletpassphrase ${WALLET_PASSPHRASE} 60
}

import_wallet_by_wif() {
    WALLET_NAME=${1:-user}
    WIF=${2}
    WALLET_PASSPHRASE=${3:-passphrase}

    if [ -z "$WIF" ]; then
        echo "WIF is required"
        exit 1
    fi

    unlock_wallet ${WALLET_NAME} ${WALLET_PASSPHRASE}
    ADDRESS=$(p2tr ${WALLET_NAME} ${WIF})
    echo "p2tr address: $ADDRESS"
    echo $ADDRESS >$WORKDIR/${WALLET_NAME}-p2tr.txt
}

p2tr() {
    WALLET_NAME=${1:-staker}

    WIF=${2}

    ORIGINAL_DESC="tr(${WIF})"
    DESC_INFO=$(bitcoin-cli -rpcwallet=${WALLET_NAME} getdescriptorinfo "$ORIGINAL_DESC")
    CHECKSUM=$(echo "$DESC_INFO" | jq -r '.checksum')
    RESULT=$(bitcoin-cli -rpcwallet=${WALLET_NAME} importdescriptors '[{ "desc": "'"$ORIGINAL_DESC"'#'"$CHECKSUM"'", "timestamp": "now", "internal": true }]')

    ADDRESS_ARRAY=$(bitcoin-cli -rpcwallet=${WALLET_NAME} deriveaddresses "$ORIGINAL_DESC#$CHECKSUM")

    ADDRESS=$(echo $ADDRESS_ARRAY | jq -r '.[0]')

    echo $ADDRESS
}

entrypoint() {
    apk add --no-cache jq
    WORKDIR=${DATADIR:-/data/.bitcoin}
    bitcoind
    while ! nc -z 127.0.0.1 18332; do
        sleep 1
    done

    createwallet_descriptors user passphrase

    USER_WIF=cPxrabgMQ1bF3WfapLcGRmn4rm8akGgMVJNLzWvSEAsqxcH6GfJF

    import_wallet_by_wif user $USER_WIF passphrase

    fund_address user $(cat $WORKDIR/user-p2tr.txt)

    list_unspent user $(cat $WORKDIR/user-p2tr.txt)

    ln -s /root/bitcoin.sh /usr/local/bin/bsh

    while true; do
        USER_ADDRESS=$(cat $WORKDIR/user-p2tr.txt)
        echo "Mining 1 block to ${USER_ADDRESS}"
        fund_address user ${USER_ADDRESS}
    done

    sleep infinity
}

fund_address() {
    WALLET_NAME=${1:-user}
    ADDRESS=${2}
    bitcoin-cli -rpcwallet=${WALLET_NAME} generatetoaddress 101 ${ADDRESS} >/dev/null 2>&1
    sleep 5
}

### Tools

### Usage: bsh <command>

list_descriptors() {
    bitcoin-cli listdescriptors
}

list_unspent() {
    WALLET_NAME=${1:-user}
    ADDRESS=${2}
    bitcoin-cli -rpcwallet=${WALLET_NAME} listunspent 6 9999999 "[\"${ADDRESS}\"]"
}

getrawtx() {
    TXID=${1}
    bitcoin-cli getrawtransaction ${TXID} true
}

gettx() {
    TXID=${1}
    WALLET_NAME=${2:-staker}
    bitcoin-cli -rpcwallet=${WALLET_NAME} gettransaction ${TXID}
}

decodepsbt() {
    PSBT=${1}
    bitcoin-cli decodepsbt ${PSBT}
}

processpsbt() {
    PSBT=${1}
    WALLET_NAME=${2:-staker}
    WALLET_PASSPHRASE=${3:-passphrase}
    unlock_wallet ${WALLET_NAME} ${WALLET_PASSPHRASE}
    bitcoin-cli -rpcwallet=${WALLET_NAME} walletprocesspsbt ${PSBT}
}

processpsbt_and_broadcast() {
    PSBT=${1}
    WALLET_NAME=${2:-staker}
    WALLET_PASSPHRASE=${3:-passphrase}
    result=$(processpsbt ${PSBT} ${WALLET_NAME} ${WALLET_PASSPHRASE})
    echo "Process Result: $result"

    if [ "$(echo $result | jq -r '.complete')" = "true" ]; then
        psbt=$(echo $result | jq -r '.psbt')
        finalize_and_broadcast ${psbt} ${WALLET_NAME} ${WALLET_PASSPHRASE}
        bitcoin-cli getrawtransaction ${txid} true
        #
    else
        echo "Failed to sign PSBT completely"
    fi
}

pab() {
    processpsbt_and_broadcast $@
}

finalize_and_broadcast() {
    PSBT=${1}
    WALLET_NAME=${2:-staker}
    WALLET_PASSPHRASE=${3:-passphrase}
    result=$(bitcoin-cli -rpcwallet=${WALLET_NAME} finalizepsbt ${PSBT})
    echo "Finalize Result: $result"
    if [ "$(echo $result | jq -r '.complete')" = "true" ]; then
        hex=$(echo $result | jq -r '.hex')
        echo "Transaction Hex: $hex"
        txid=$(bitcoin-cli sendrawtransaction ${hex})
        echo "Transaction broadcast, txid: $txid"
    else
        echo "Failed to finalize PSBT"
    fi
}

$@
