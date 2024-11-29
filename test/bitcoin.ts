import Client from "bitcoin-core-ts";

type BtcUnspent = {
  txid: string;
  vout: number;
  address: string;
  label?: string;
  scriptPubKey: string;
  amount: number;
  confirmations: number;
  spendable: boolean;
  solvable: boolean;
  desc: string;
  parent_descs?: string[];
  safe: boolean;
};

// TODO: If want to use mempool api, please visit https://mempool.space/docs/api/rest

export const getUtxoss = async (
  address: string,
  btcClient: Client
): Promise<BtcUnspent[]> => {
  const listUnspent: BtcUnspent[] = await btcClient.command(
    "listunspent",
    1,
    9999999,
    [address],
    true,
    { minimumAmount: 1 / 100000 }
  );
  return listUnspent;
};

export const sendrawtransaction = async (
  hex: string,
  btcClient: Client
): Promise<string> => {
  const txid = await btcClient.command("sendrawtransaction", hex);
  return txid;
};

export const testmempoolaccept = async (
  hex: string,
  btcClient: Client
): Promise<any> => {
  return await btcClient.command("testmempoolaccept", [hex]);
};
