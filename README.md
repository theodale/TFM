# The Field Machine 🔥

The options infrastructure of the future.

### Architecture

The Field Machine consists of the following principal two smart contract layers:

- `ActionLayer`: contains option-related functionality.
- `AssetLayer`: carrys out all the protocol's token-related operations.

In addition to these two main components, the protocol uses two further smart contracts:

- `TrufinWallet`: Used to hold assets on a per-user basis to prevent mixing and potential contamination.
- `Validator`: An on-chain library delegated to by the `ActionLayer` in order to perform signature verifications.
