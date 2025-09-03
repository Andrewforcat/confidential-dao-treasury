import { expect } from "chai";
import { ethers, fhevm } from "hardhat";
import { FhevmType } from "@fhevm/hardhat-plugin";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("Confidential DAO Treasury", function () {
  let owner: HardhatEthersSigner;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;
  let carol: HardhatEthersSigner;

  let treasury: any;
  let addr: string;

  beforeEach(async () => {
    [owner, alice, bob, carol] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("ConfidentialTreasury");
    treasury = await Factory.deploy(
      [owner.address, alice.address, bob.address], // initial members
      2                                           // quorum
    );
    addr = await treasury.getAddress();
  });

  it("encrypted treasury starts uninitialized; deposit and decrypt as owner", async () => {
    const t0 = await treasury.getTreasury();
    expect(t0).to.eq(ethers.ZeroHash); // uninitialized ciphertext

    // owner deposits 1000
    const enc1000 = await fhevm.createEncryptedInput(addr, owner.address).add64(1000).encrypt();
    await (await treasury.connect(owner).depositEncrypted(enc1000.handles[0], enc1000.inputProof)).wait();

    const encTreasury = await treasury.getTreasury();
    const clearTreasury = await fhevm.userDecryptEuint(FhevmType.euint64, encTreasury, addr, owner);
    expect(clearTreasury).to.eq(1000);
  });

  it("proposal executes if quorum met; executedEnc equals requested; treasury reduced", async () => {
    // deposit 1000
    const enc1000 = await fhevm.createEncryptedInput(addr, owner.address).add64(1000).encrypt();
    await (await treasury.connect(owner).depositEncrypted(enc1000.handles[0], enc1000.inputProof)).wait();

    // create proposal request 600 to carol
    const enc600 = await fhevm.createEncryptedInput(addr, alice.address).add64(600).encrypt();
    const tx = await treasury.connect(alice).createProposal(carol.address, enc600.handles[0], enc600.inputProof, 3600);
    const receipt = await tx.wait();
    const id = Number(receipt?.logs?.[0]?.args?.[0] ?? 0);

    // votes: alice + bob
    await (await treasury.connect(alice).voteYes(id)).wait();
    await (await treasury.connect(bob).voteYes(id)).wait();

    // execute
    await (await treasury.connect(owner).execute(id)).wait();

    // executed amount is 600 for recipient
    const encExecuted = await treasury.getExecutedAmount(id);
    const clearExecuted = await fhevm.userDecryptEuint(FhevmType.euint64, encExecuted, addr, carol);
    expect(clearExecuted).to.eq(600);

    // treasury = 1000 - 600 = 400 (owner can decrypt)
    const encTreasury = await treasury.getTreasury();
    const clearTreasury = await fhevm.userDecryptEuint(FhevmType.euint64, encTreasury, addr, owner);
    expect(clearTreasury).to.eq(400);
  });

  it("fail-closed: request > treasury leads to executedEnc == 0; treasury unchanged", async () => {
    // deposit 500
    const enc500 = await fhevm.createEncryptedInput(addr, owner.address).add64(500).encrypt();
    await (await treasury.connect(owner).depositEncrypted(enc500.handles[0], enc500.inputProof)).wait();

    // proposal asks for 9999
    const enc9999 = await fhevm.createEncryptedInput(addr, alice.address).add64(9999).encrypt();
    const create = await treasury.connect(alice).createProposal(carol.address, enc9999.handles[0], enc9999.inputProof, 3600);
    const r = await create.wait();
    const id = Number(r?.logs?.[0]?.args?.[0] ?? 0);

    await (await treasury.connect(alice).voteYes(id)).wait();
    await (await treasury.connect(bob).voteYes(id)).wait();

    await (await treasury.connect(owner).execute(id)).wait();

    // executed == 0 for recipient
    const encExecuted = await treasury.getExecutedAmount(id);
    const clearExecuted = await fhevm.userDecryptEuint(FhevmType.euint64, encExecuted, addr, carol);
    expect(clearExecuted).to.eq(0);

    // treasury still 500
    const encTreasury = await treasury.getTreasury();
    const clearTreasury = await fhevm.userDecryptEuint(FhevmType.euint64, encTreasury, addr, owner);
    expect(clearTreasury).to.eq(500);
  });
});
