const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { getOracleNonceSignature } = require("../helpers/oracle/nonce.js");
const { freshDeployment } = require("../helpers/fixtures.js");

describe("NONCE", () => {
  beforeEach(async () => {
    ({ ActionLayer: this.ActionLayer, oracle: this.oracle } = await loadFixture(
      freshDeployment
    ));
  });

  it("Updates nonce to input value", async () => {
    const newNonce = 1234;

    const oracleSignature = await getOracleNonceSignature(
      this.oracle,
      newNonce
    );

    await this.ActionLayer.updateOracleNonce(newNonce, oracleSignature);

    expect(await this.ActionLayer.oracleNonce()).to.equal(1234);
  });
});
