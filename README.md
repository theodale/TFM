# The Field Machine 🔥

The options infrastructure of the future.

### Architecture

The Field Machine consists of two principal smart contract layers.

- `ActionLayer`: contains option-related functionality.
- `AssetLayer`: carrys out all the protocol's token-related operations.

In addition to these two main components, a `TrufinWallet` is used to hold user funds and a `Validator` library is delegated to by the `ActionLayer` in order to perform signature verifications.
