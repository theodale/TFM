# Trufin Protocol 🔥

The options layer of the future.

### Oracle

- The TF oracle signs a set of terms for a potential action.
- These are trusted as valid data on-chain.

### TODO

- Ensure full fee flexibilty. For example, in transfers, a fee can only be charged to the sender and recipient.
- Ask about exercise -> two step? DoS possibility?
- Liquidation never involves the deletion of a strategy?

1 - withdraw
2 - liq + exercise

### Web2

- Ensure only signing transfer/combinations/novations for non expired strategies
- Sigature replay across different strategies => e.g. mint two with same expiry, phase, bra, etc... => ensure have strategy IDs in the message hashes
- The combination strategies resulting form has to be signed so that it can be used in a strategy with the first strategy's (`strategyOne`) alpha and omega => i.e. in that direction.

### Ideas

- Do we need a liquidate nonce to prevent replay of liq sigs
