const { expect } = require("chai");
const { ethers, BigNumber } = require("hardhat");

describe("SeedSales E2E test", function () {
  let busd, gowToken, seedSales, buyer, timestamp;
  accounts = [];
  let wait;
  
  beforeEach(async () => {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    buyer = accounts[1];
    tokenReceiver = accounts[2];
    secondtokenReceiver = accounts[3];

   await ethers.provider.getBlockNumber().then(function(blockNumber) {
      ethers.provider.getBlock(blockNumber).then(function(block) {
        timestamp = block.timestamp;
      });
  });
   wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  });

  it("Should deploy the contracts and mint busd", async function () {
    const Busd = await ethers.getContractFactory("BUSDImplementation");
    const GowToken = await ethers.getContractFactory("GowToken");
    const SeedSales = await ethers.getContractFactory("SeedSales");
    busd = await Busd.deploy();
    gowToken = await GowToken.deploy("100000000");
    seedSales = await SeedSales.deploy(gowToken.address, busd.address);
    await busd.deployed();
    await gowToken.deployed();
    await seedSales.deployed();

    const unPausedBusd = await busd.unpause();
    unPausedBusd.wait();
    const mintBusdToken = await busd.increaseSupply("10000000000000000000000000");
    mintBusdToken.wait();
    expect(await busd.paused()).to.equal(false);
    expect(await busd.totalSupply()).to.equal("10000000000000000000000000");
    expect(await gowToken.totalSupply()).to.equal("100000000000000000000000000");
    expect(await seedSales.paused()).to.equal(false);
  })

  it("Should create Admin and Distribute GOW tokens", async function () {
    const makeAdmin = await gowToken.addAdmins(seedSales.address);
    const distributeGowToken = await gowToken.transfer(seedSales.address, "1000000000000000000000000");
    makeAdmin.wait();
    distributeGowToken.wait();
    expect(await gowToken.admins(seedSales.address)).to.equal(true);
    expect(await gowToken.balanceOf(seedSales.address)).to.equal("1000000000000000000000000");
  })

  it("Should create vesting period", async function () {
    const vestingPeriodOne = await seedSales.setVestingPeriod("1", "20", "3");
    const vestingPeriodTwo = await seedSales.setVestingPeriod("2", "40", "6");
    const vestingPeriodThree = await seedSales.setVestingPeriod("3", "60", "9");
    vestingPeriodOne.wait();
    vestingPeriodTwo.wait();
    vestingPeriodThree.wait();
    
    const vestingPeriodOneData = await seedSales.vestingPeriod("1");
    const vestingPeriodTwoData = await seedSales.vestingPeriod("2");
    const vestingPeriodThreeData = await seedSales.vestingPeriod("3");
    expect(vestingPeriodOneData.releaseAmount.toString()).to.equal((3).toString());
    expect(vestingPeriodTwoData.releaseAmount.toString()).to.equal((6).toString());
    expect(vestingPeriodThreeData.releaseAmount.toString()).to.equal((9).toString());

  })

  it("Should buy seed sales tokens", async function () {
    const transferBuyerBusd = await busd.transfer(buyer.address, "1000000000000000000000");
    const approveSeedSales = await busd.connect(buyer).approve(seedSales.address, "100000000000000000000");
    const buySeedSalesToken = await seedSales.connect(buyer).buygowToken(60);
    transferBuyerBusd.wait();
    approveSeedSales.wait();
    buySeedSalesToken.wait();
    let percent = 3;

    const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, 0);
    expect(tokenHolderBalance.tokenClaimable.toString()).to.equal(ethers.utils.parseUnits((60 / 0.04 * 5/100).toString(),"ether"));

    for (let index = 1; index < 4; index++) {
      const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, index);
      expect(tokenHolderBalance.tokenClaimable.toString()).to.equal(ethers.utils.parseUnits((60 / 0.04 * percent/100).toString(),"ether"));
      percent +=3;
    }

    balance = await gowToken.balanceOf(buyer.address);
    expect(balance.toString()).to.equal(ethers.utils.parseUnits((60/0.04).toString(),"ether"));
  })

  it("Should allow user withdraw first vested tokens", async function () {
    const stopGap = await gowToken.stopGap(buyer.address);
    // console.log('StopGap>>>',stopGap);

    const withdrawFirstVestedTokens = await gowToken.connect(buyer).transfer(tokenReceiver.address, ethers.utils.parseUnits((60 / 0.04 * 3/100).toString(), "ether"));
    withdrawFirstVestedTokens.wait();
    const withdrawFirstVestedTokens2 = await gowToken.connect(buyer).transfer(tokenReceiver.address, ethers.utils.parseUnits((60 / 0.04 * 2/100).toString(), "ether"));
    withdrawFirstVestedTokens2.wait();
  
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));
    const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, 0);
    expect(await gowToken.balanceOf(tokenReceiver.address)).to.equal(ethers.utils.parseUnits((60/0.04 * 5/100).toString(),"ether"));
    expect(await tokenHolderBalance.tokenClaimable).to.equal(0);
    expect(await tokenHolderBalance.tokenClaimed).to.equal(true);
  })

  it("Should release vested tokens", async function () {
    const releaseVestedToken = await seedSales.connect(admin).releaseVestedToken( "1");
    const releaseVestedToken1 = await seedSales.connect(admin).releaseVestedToken( "2");
    const releaseVestedToken2 = await seedSales.connect(admin).releaseVestedToken( "3");
    releaseVestedToken.wait();
    releaseVestedToken1.wait();
    releaseVestedToken2.wait();

    const vestingPeriodOneData = await seedSales.vestingPeriod("1");
    const vestingPeriodTwoData = await seedSales.vestingPeriod("2");
    const vestingPeriodThreeData = await seedSales.vestingPeriod("3");
    expect(vestingPeriodOneData.released).to.equal(true);
    expect(vestingPeriodTwoData.released).to.equal(true);
    expect(vestingPeriodThreeData.released).to.equal(true);
  })

  it("Should allow user withdraw second vested tokens", async function () {
    this.timeout(timestamp + 1000);
    await wait(1 * 20 * 1000);

    const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, 1);
    const tokenHolderBalance1 = await gowToken.tokenHolders(buyer.address, 2);
    expect(await tokenHolderBalance.vestingEnd.toNumber()).to.lessThanOrEqual(timestamp + 20);
    expect(await tokenHolderBalance.tokenClaimed).to.equal(false);
    expect(await tokenHolderBalance.vestingRelease).to.equal(true);
    expect(await tokenHolderBalance1.vestingEnd.toNumber()).to.greaterThan(timestamp + 30);
    expect(Number(await tokenHolderBalance.tokenClaimable)).to.equal(Number(ethers.utils.parseUnits((60 / 0.04 * 3/100).toString(), "ether")));
    // console.log('StopGap>>>',await gowToken.stopGap(buyer.address));

    const withdrawSecondVestedTokens = await gowToken.connect(buyer).transfer(tokenReceiver.address, ethers.utils.parseUnits((60 / 0.04 * 3/100).toString(), "ether"));
    withdrawSecondVestedTokens.wait();
  
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));

    const tokenHolderBalanceAfter = await gowToken.tokenHolders(buyer.address, 1);
    expect(await tokenHolderBalanceAfter.tokenClaimable).to.equal(0);
    expect(await tokenHolderBalanceAfter.tokenClaimed).to.equal(true);

  })

  it("Should allow user withdraw third vested tokens", async function () {
    this.timeout(timestamp + 3000);
    await wait(1 * 20 * 1000);

    const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, 2);
    const tokenHolderBalance1 = await gowToken.tokenHolders(buyer.address, 3);
    expect(await tokenHolderBalance.vestingEnd.toNumber()).to.lessThanOrEqual(timestamp + 30);
    expect(await tokenHolderBalance.tokenClaimed).to.equal(false);
    expect(await tokenHolderBalance.vestingRelease).to.equal(true);
    expect(await tokenHolderBalance1.vestingEnd.toNumber()).to.greaterThan(timestamp);
    expect(Number(await tokenHolderBalance.tokenClaimable)).to.equal(Number(ethers.utils.parseUnits((60 / 0.04 * 6/100).toString(), "ether")));
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));

    const withdrawSecondVestedTokens = await gowToken.connect(buyer).transfer(tokenReceiver.address, ethers.utils.parseUnits((60 / 0.04 * 6/100).toString(), "ether"));
    withdrawSecondVestedTokens.wait();
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));
    const tokenHolderBalanceAfter = await gowToken.tokenHolders(buyer.address, 2);
    expect(await tokenHolderBalanceAfter.tokenClaimable).to.equal(0);
    expect(await tokenHolderBalanceAfter.tokenClaimed).to.equal(true);

  })

  it("Should allow user withdraw fourth vested tokens", async function () {
    this.timeout(timestamp + 3000);
    await wait(1 * 20 * 1000);

    const tokenHolderBalance = await gowToken.tokenHolders(buyer.address, 3);
    // const tokenHolderBalance1 = await gowToken.tokenHolders(buyer.address, 3);
    expect(await tokenHolderBalance.vestingEnd.toNumber()).to.lessThanOrEqual(timestamp + 50);
    expect(await tokenHolderBalance.tokenClaimed).to.equal(false);
    expect(await tokenHolderBalance.vestingRelease).to.equal(true);
    // expect(await tokenHolderBalance1.vestingEnd.toNumber()).to.greaterThan(timestamp);
    expect(Number(await tokenHolderBalance.tokenClaimable)).to.equal(Number(ethers.utils.parseUnits((60 / 0.04 * 9/100).toString(), "ether")));
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));

    const withdrawFourthVestedTokens = await gowToken.connect(buyer).transfer(tokenReceiver.address, ethers.utils.parseUnits((60 / 0.04 * 9/100).toString(), "ether"));
    withdrawFourthVestedTokens.wait();
    // console.log('StopGap>>>', await gowToken.stopGap(buyer.address));
    const tokenHolderBalanceAfter = await gowToken.tokenHolders(buyer.address, 3);
    expect(await tokenHolderBalanceAfter.tokenClaimable).to.equal(0);
    expect(await tokenHolderBalanceAfter.tokenClaimed).to.equal(true);

  })

  it("Should allow user withdraw tokens", async function () {
    const transferToken = await gowToken.connect(buyer).transfer(secondtokenReceiver.address, ethers.utils.parseUnits((50).toString(), "ether"));
    transferToken.wait();
    expect(await gowToken.balanceOf(secondtokenReceiver.address)).to.equal(ethers.utils.parseUnits((50).toString(), "ether"));
  })

});

