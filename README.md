# Trufin Protocol 🔥

The options layer of the future.

### Strategies

- Strategies are combinations of one or more options held between two users.

##### Actions

- Users holding positions may perform the following actions on their strategies:
  - Minting
  - Transferring
  - Combining
  - Novating
  - Exercising

### Novation

- Novation signed data is offered by oracle for

### Oracle

- The TF oracle signs a set of terms for a potential action.
- These are trusted as valid data on-chain.

### Web2

- Ensure only signing transfer/combinations/novations for non expired strategies
- Sigature replay across different strategies => e.g. mint two with same expiry, phase, bra, etc... => ensure have strategy IDs in the message hashes
- The combination strategies resulting form has to be signed so that it can be used in a strategy with the first strategy's (`strategyOne`) alpha and omega => i.e. in that direction.
