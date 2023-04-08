const { mintAndDeposit } = require("../collateral-management.js");
const { getTransferTerms } = require("../terms/transfer.js");
const { signTransfer } = require("../signing/transfer.js");

const transfer = async (
  TFM,
  CollateralManager,
  Basis,
  strategyId,
  oracle,
  recipientCollateralRequirement,
  recipientFee,
  senderFee,
  premium,
  sender,
  recipient,
  staticParty = null
) => {
  await CollateralManager.connect(recipient).createWallet();

  const strategy = await TFM.getStrategy(strategyId);

  let alphaTransfer;

  if (sender.address == strategy.alpha) {
    alphaTransfer = true;
  } else {
    alphaTransfer = false;
  }

  // DEPOSIT REQUIRED COLLATERAL

  let senderDeposit = senderFee;
  let recipientDeposit = recipientFee.add(recipientCollateralRequirement);

  if (premium > 0) {
    senderDeposit = senderDeposit.add(premium);
  } else {
    recipientDeposit = recipientDeposit.sub(premium);
  }

  // Post required collateral
  await mintAndDeposit(CollateralManager, Basis, sender, senderDeposit);
  await mintAndDeposit(CollateralManager, Basis, recipient, recipientDeposit);

  // TRANSFER

  const { oracleSignature, transferTerms } = await getTransferTerms(
    TFM,
    strategyId,
    oracle,
    recipientCollateralRequirement,
    senderFee,
    recipientFee,
    alphaTransfer
  );

  const transferParameters = await signTransfer(
    sender,
    recipient,
    staticParty,
    oracleSignature,
    strategyId,
    premium,
    TFM
  );

  const transferTransaction = await TFM.transfer(
    transferTerms,
    transferParameters
  );

  return transferTransaction;
};

module.exports = {
  transfer,
};
