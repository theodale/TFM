const { getOracleTransferSignature } = require("../oracle/transfer.js");
const { signTransfer } = require("../signing/transfer.js");
const { mintAndDeposit } = require("../utils.js");

const transfer = async (
  TFM,
  FundManager,
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
  const recipientWallet = await FundManager.wallets(recipient.address);

  if (recipientWallet == ethers.constants.AddressZero) {
    await FundManager.connect(recipient).createWallet();
  }

  const strategy = await TFM.getStrategy(strategyId);

  let alphaTransfer;

  // May break if alpha == omega
  if (sender.address == strategy.alpha) {
    alphaTransfer = true;
  } else {
    alphaTransfer = false;
  }

  let senderDeposit = senderFee;
  let recipientDeposit = recipientFee.add(recipientCollateralRequirement);

  if (premium > 0) {
    senderDeposit = senderDeposit.add(premium);
  } else {
    recipientDeposit = recipientDeposit.sub(premium);
  }

  await mintAndDeposit(sender, senderDeposit, Basis, FundManager);
  await mintAndDeposit(recipient, recipientDeposit, Basis, FundManager);

  const oracleSignature = await getOracleTransferSignature(
    TFM,
    strategyId,
    oracle,
    recipientCollateralRequirement,
    senderFee,
    recipientFee,
    alphaTransfer
  );

  const senderSignature = await signTransfer(
    sender,
    recipient,
    oracleSignature,
    strategyId,
    premium,
    TFM
  );

  const recipientSignature = await signTransfer(
    recipient,
    recipient,
    oracleSignature,
    strategyId,
    premium,
    TFM
  );

  const oracleNonce = await TFM.oracleNonce();

  let staticPartySignature = "0x";

  // if (!strategy.transferable) {
  //   staticPartySignature = await signTransfer(staticParty);
  // }

  const transferParameters = [
    strategyId,
    recipient.address,
    premium,
    oracleSignature,
    senderSignature,
    recipientSignature,
    staticPartySignature,
    recipientCollateralRequirement,
    oracleNonce,
    senderFee,
    recipientFee,
    alphaTransfer,
  ];

  const transferTransaction = await TFM.transfer(transferParameters);

  return transferTransaction;
};

module.exports = {
  transfer,
};
