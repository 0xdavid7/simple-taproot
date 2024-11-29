import Client from "bitcoin-core-ts";
import * as bitcoin from "bitcoinjs-lib";
import { z } from "zod";

import ECPairFactory from "ecpair";
import * as ecc from "tiny-secp256k1";

const ProjectEnvSchema = z.object({
  PRIVATE_KEY: z.string().min(10),
  ADDRESS: z.string().min(10),
});

export const ProjectEnv = ProjectEnvSchema.parse({
  PRIVATE_KEY: process.env.PRIVATE_KEY,
  ADDRESS: process.env.ADDRESS,
});

const MOCK_RECIPIENT_ADDRESS =
  "bcrt1pj5pn6j9kq2ghfmfm5gfeqatv2m5scs0wam6pc9evs8gapxsk0ndqzagfze";

console.log("ProjectEnv", ProjectEnv);

export const setUpTest = () => {
  bitcoin.initEccLib(ecc);
  const eccFactory = ECPairFactory(ecc);

  const btcClient = new Client({
    network: "regtest",
    host: "localhost",
    port: "18332",
    wallet: "user",
    username: "user",
    password: "password",
  });

  const network = bitcoin.networks.regtest;

  const keyPair = eccFactory.fromWIF(ProjectEnv.PRIVATE_KEY, network);

  return {
    btcClient,
    keyPair,
    address: ProjectEnv.ADDRESS,
    recipient: MOCK_RECIPIENT_ADDRESS,
    network,
  };
};

export function logToJSON(any: any) {
  console.log(
    JSON.stringify(
      any,
      (k, v) => {
        if (v.type === "Buffer") {
          return Buffer.from(v.data).toString("hex");
        }
        if (k === "network") {
          switch (v) {
            case bitcoin.networks.bitcoin:
              return "bitcoin";
            case bitcoin.networks.testnet:
              return "testnet";
            case bitcoin.networks.regtest:
              return "regtest";
          }
        }
        if (typeof v == "bigint") {
          return v.toString(10);
        }
        return v;
      },
      2
    )
  );
}
