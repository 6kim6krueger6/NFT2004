const {expect} = require('chai');
const {deployments, ethers} = require('hardhat');

describe("NFT", async function (){
    beforeEach({
        async function () {
            // const deplo
            await deployments.fixture(["all"]);
            NFT = await ethers.getContract("NFT");
        }
    })
    describe("constructor", async function (){})
})