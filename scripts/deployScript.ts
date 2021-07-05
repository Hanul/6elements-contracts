import hardhat from "hardhat";

async function main() {
    console.log("deploy start")

    const SixElements = await hardhat.ethers.getContractFactory("SixElements")
    const sixElements = await SixElements.deploy()
    console.log(`6 Elements address: ${sixElements.address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
