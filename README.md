## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```


## Deploy And Verify
```shell
forge create --rpc-url $RPC_URL \
--constructor-args $TOKEN_ADDRESS $TOKEN_PRICE start end \
--private-key $PRIVATE_KEY src/Presale.sol:Presale \
--etherscan-api-key $ETHERSCAN_API_KEY \
--verify
```
### Replace start and end with the relevant timestamps in seconds