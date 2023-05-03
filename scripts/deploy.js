// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    const { network, run } = hre

    const ESE = await hre.ethers.getContractFactory("ESE");
    const minter = await hre.ethers.getContractFactory("eeseeMinter");
    const pool = await hre.ethers.getContractFactory("eeseePool");
    const eesee = await hre.ethers.getContractFactory("eesee");
    let args
    args = ['1000000000000000000000000000']
    const _ESE = await ESE.deploy(...args)
    await _ESE.deployTransaction.wait(6);
    await run("verify:verify", {
        address: _ESE.address,
        constructorArguments: args
    })

    args = ['','']//TODO
    const _minter = await minter.deploy(...args)
    await _minter.deployTransaction.wait(6);
    await run("verify:verify", {
        address: _minter.address,
        constructorArguments: args
    })
    
    args = [_ESE.address]
    const _pool = await pool.deploy(...args)
    await _pool.deployTransaction.wait(6)
    await run("verify:verify", {
        address: _pool.address,
        constructorArguments: args
    })

    let _eesee
    if(network.name === 'goerli'){
        //goerli testnet
        args = [
            _ESE.address, 
            _minter.address,
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', 
            '0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f',//royaltyEngine
            '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',//vrfCoordinator
            '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',//ChainLink token
            '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',//150 gwei hash
            3,//minimumRequestConfirmations
            50000//callbackGasLimit
        ]
    }else if(network.name === 'ethereum'){
        args = [
            _ESE.address, 
            _minter.address,
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', //TODO
            '0x0385603ab55642cb4Dd5De3aE9e306809991804f',//royaltyEngine
            '0x271682DEB8C4E0901D1a1550aD2e64D568E69909',//vrfCoordinator
            '0x514910771AF9Ca656af840dff83E8264EcF986CA',//ChainLink token
            '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef',//150 gwei hash
            13,//minimumRequestConfirmations
            50000//callbackGasLimit
        ]
    }else if(network.name === 'polygon'){
        args = [
            _ESE.address, 
            _minter.address, 
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', //TODO
            '0x28EdFcF0Be7E86b07493466e7631a213bDe8eEF2',//royaltyEngine
            '0xAE975071Be8F8eE67addBC1A82488F1C24858067',//vrfCoordinator
            '0xb0897686c545045aFc77CF20eC7A532E3120E0F1',//ChainLink token
            '0x6e099d640cde6de9d40ac749b4b594126b0169747122711109c9985d47751f93',//200 gwei hash
            13,//minimumRequestConfirmations
            50000//callbackGasLimit
        ]
    }else{
        return
    }

    _eesee = await eesee.deploy(...args)
    await _eesee.deployTransaction.wait(6);

    await run("verify:verify", {
        address: _eesee.address,
        constructorArguments: args,
    })

    console.log(`eesee: ${_eesee.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
