# Simple Taproot Bitcoin Transaction Demo

### Prerequisites

- Bun
- Docker

### How to start

Run

```
./bitcoin.sh run
```

- This will start a Bitcoin node in `regtest` mode.
- Then import the private key (wif) of the wallet into the Bitcoin node.
- Finally, it dumps an taproot address into the `.bitcoin/user-p2tr.txt` file.
- Copy the address and replace in the `.env` file. Eg `bcrt1p...`

### How to run the tests

```
bun test test/e2e.test.ts
```

### Useful commands

- Check the `bitcoin.sh`
- Usage: `bsh <command>`
