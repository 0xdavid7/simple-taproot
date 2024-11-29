import { describe, it } from "bun:test";
import { logToJSON, setUpTest } from "./suite";
import { getUtxoss, sendrawtransaction, testmempoolaccept } from "./bitcoin";
import * as bitcoin from "bitcoinjs-lib";
import { toXOnly } from "bitcoinjs-lib/src/psbt/bip371";

//Start local regtest bitcoin node before running the test
describe("Should create, sign and broadcast taproot key path psbt", async () => {
  const TestSuite = setUpTest();
  it("test1", async () => {
    const utxos = await getUtxoss(TestSuite.address, TestSuite.btcClient);
    const MOCK_FEE = 200;

    const { version, data } = bitcoin.address.fromBech32(TestSuite.address);
    if (version !== 1 || data.length !== 32) {
      throw new Error("Address is not a taproot address");
    }

    const unsignedPsbt = new bitcoin.Psbt();
    const input = utxos[0];
    const inputAmount = BigInt(input.amount * 1e8);

    const recipientOutputScript = bitcoin.address.toOutputScript(
      TestSuite.recipient,
      TestSuite.network
    );

    const senderOutputScript = bitcoin.address.toOutputScript(
      TestSuite.address,
      TestSuite.network
    );

    console.log("recipientOutputScript", recipientOutputScript);
    console.log("senderOutputScript", senderOutputScript);

    unsignedPsbt.addInput({
      hash: input.txid,
      index: input.vout,
      witnessUtxo: {
        script: senderOutputScript,
        value: inputAmount,
      },
      sequence: 0xfffffffe, // RBF, can set to 0xffffffff to make it non-RBF
      tapInternalKey: toXOnly(TestSuite.keyPair.publicKey),
    });

    unsignedPsbt.addOutput({
      script: recipientOutputScript,
      value: inputAmount - BigInt(MOCK_FEE),
    });

    console.log("Before signing");

    console.log("PSBT base64", unsignedPsbt.toBase64());

    for (let i = 0; i < unsignedPsbt.txInputs.length; i++) {
      const tweakedSigner = TestSuite.keyPair.tweak(
        bitcoin.crypto.taggedHash(
          "TapTweak",
          toXOnly(TestSuite.keyPair.publicKey)
        )
      );

      unsignedPsbt.signTaprootInput(i, tweakedSigner);
    }

    unsignedPsbt.finalizeAllInputs();

    console.log("After signing");

    console.log("PSBT base64", unsignedPsbt.toBase64());

    logToJSON(unsignedPsbt);

    const signedPsbt = unsignedPsbt.extractTransaction();

    const txHex = signedPsbt.toHex();

    console.log("txHex", txHex);

    const result = await testmempoolaccept(txHex, TestSuite.btcClient);

    logToJSON(result);

    const txid = await sendrawtransaction(txHex, TestSuite.btcClient);

    console.log("txid", txid);
  });
});
