const { expect } = require("chai");
const { ethers, BigNumber } = require("hardhat");

describe("Airdrop Token test", function () {
  let  gowToken, airdrop, referrer, referral1, referral2, referral3, emptyreferrer, timestamp;
  accounts = [];
  let wait;
  
  beforeEach(async () => {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    referrer = accounts[1];
    tokenReceiver = accounts[2];
    referral1 = accounts[3];
    referral2 = accounts[4];
    referral3 = accounts[5];
    emptyreferrer = "0x0000000000000000000000000000000000000000" ;

   await ethers.provider.getBlockNumber().then(function(blockNumber) {
      ethers.provider.getBlock(blockNumber).then(function(block) {
        timestamp = block.timestamp;
      });
  });
   wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  });

  it("Should deploy the contracts and mint gowToken", async function () {
    const GowToken = await ethers.getContractFactory("GowToken");
    const Airdrop = await ethers.getContractFactory("Airdrop");
 
    gowToken = await GowToken.deploy("100000000");
    airdrop = await Airdrop.deploy(gowToken.address);

    await gowToken.deployed();
    await airdrop.deployed();

    expect(await gowToken.totalSupply()).to.equal("100000000000000000000000000");
    expect(await airdrop.paused()).to.equal(false);
  })

  it("Should create Admin and Distribute GOW tokens", async function () {
    const makeAdmin = await gowToken.addAdmins(airdrop.address);
    const distributeGowToken = await gowToken.transfer(airdrop.address, "1000000000000000000000000");
    makeAdmin.wait();
    distributeGowToken.wait();

    expect(await gowToken.admins(airdrop.address)).to.equal(true);
    expect(await gowToken.balanceOf(airdrop.address)).to.equal("1000000000000000000000000");
  })

  it("Should apply for Airdrop without Referrer", async function () {
    const getAirdrop = await airdrop.connect(referrer).airdropWhitelist(emptyreferrer);
    getAirdrop.wait();

    expect(await airdrop.airdropClaimWhitelist(referrer.address)).to.equal(true);
  })

  it("Should apply for Airdrop with 2 Referrer", async function () {
    const getAirdrop = await airdrop.connect(referral1).airdropWhitelist(referrer.address);
    const getAirdrop1 = await airdrop.connect(referral2).airdropWhitelist(referrer.address);
    getAirdrop.wait();
    getAirdrop1.wait();
    let countArray = [];
    countArray = await airdrop.getReferral(referrer.address);
    expect(countArray.length).to.equal(2);
  })

  it("Should apply for Airdrop with 1 Referrer", async function () {
    const getAirdrop = await airdrop.connect(referral3).airdropWhitelist(referral2.address);
    getAirdrop.wait();
    let countArray = [];
    countArray = await airdrop.getReferral(referral2.address);
    expect(countArray.length).to.equal(1);
  })

  it("Should approve token for distribution", async function () {
    const approve = await airdrop.connect(admin).approveAirdrop(10);
    approve.wait();
    
    // const getApproved = await gowToken.tokenHolders(referrer.address,0);
    const tokenBalance = await gowToken.allowance(airdrop.address, referrer.address);
    // expect(getApproved.vestingRelease).to.equal(true);
    expect(tokenBalance.toString()).to.equal("250000000000000000000");
    })

  it("Should withdraw token to own address after Approval", async function () {
    const transfer = await gowToken.connect(referrer).transferFrom(airdrop.address, referrer.address, "250000000000000000000");
    transfer.wait();

    const getBalance = await gowToken.balanceOf(referrer.address);
    expect(getBalance).to.equal("250000000000000000000");
  })

  it("Should transfer token after withdrawal", async function () {
    this.timeout(timestamp + 1000);
    await wait(1 * 12 * 1000);
    const holdLength = await gowToken.tokenHolders(referrer.address,1);
    const transfer = await gowToken.connect(referrer).transfer(tokenReceiver.address, "250000000000000000000");
    transfer.wait();

    const getBalance = await gowToken.balanceOf(tokenReceiver.address);
    expect(getBalance).to.equal("250000000000000000000");
  })

})