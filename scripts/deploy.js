const { ethers, run, network } = require("hardhat");

async function main() {
    const NFT = await ethers.getContractFactory("NFT");
    console.log("Deploying contract...");
    const nft = await NFT.deploy();

    if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
        console.log("Waiting for block confirmations...");
        await nft.deployTransaction.wait(6);
        await verify(nft.address, []);
    }
    console.log(`NFT deployed to ${nft.address}`);
}

const verify = async(contractAddress, args) => {
    console.log("Verifying contract...");
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        });
    } catch (error) {
        if(error.message.toLowerCase().includes("already verified")){
            console.log("Already verified!");
        }else{
            console.log(error);
        }
    }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })