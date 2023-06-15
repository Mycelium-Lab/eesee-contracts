// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { network, run, ethers } = require("hardhat");
const { getContractAddress } = require('@ethersproject/address')

async function verify(contract, constructorArguments, name){
    console.log('...Deploying ' + name)
    await contract.deployTransaction.wait(4);
    console.log('...Verifying on block explorer ' + name)
    try {
        await run("verify:verify", {
            address: contract.address,
            constructorArguments: constructorArguments,
            contract: name
        })
    } catch (error) {
        console.log(error)
    }
}
async function main() {
    const ESE = await ethers.getContractFactory("ESE");
    const minter = await ethers.getContractFactory("eeseeMinter");
    const pool = await ethers.getContractFactory("eeseeMiningRewardsPool");
    const eesee = await ethers.getContractFactory("eesee");

    let month = 60*60*24*365/12
    let args = [
        {//presale
            cliff: month*6,
            duration: month*18,
            TGEMintShare: 1000,
            beneficiaries: []
        },
        {//private sale
            cliff: month*6,
            duration: month*18,
            TGEMintShare: 1000,
            beneficiaries: []
        },
        {//public sale
            cliff: month*2,
            duration: month*10,
            TGEMintShare: 1500,
            beneficiaries: []
        },
        {//teamAndAdvisors
            cliff: month*10,
            duration: month*38,
            TGEMintShare: 10000,//TODO: change to 0
            beneficiaries: [{addr: signer.address, amount: '1000000000000000000000000000'}]
        },
        {//marketplaceMining
            cliff: 0,
            duration: month*70,
            TGEMintShare: 0,
            beneficiaries: []
        },
        {//staking
            cliff: 0,
            duration: month*36,
            TGEMintShare: 0,
            beneficiaries: []
        }
    ]
    const _ESE = await ESE.deploy(...args)
    await verify(_ESE, args, "contracts/ESE.sol:ESE")

    args = ['','']//TODO
    const _minter = await minter.deploy(...args)
    await verify(_minter, args, "contracts/NFT/eeseeMinter.sol:eeseeMinter")
    
    args = [_ESE.address]
    const _pool = await pool.deploy(...args)
    await verify(_pool, args, "contracts/eeseeMiningRewardsPool.sol:eeseeMiningRewardsPool")

    let _eesee
    if(network.name === 'goerli'){
        //goerli testnet
        const Mock1InchExecutor = await ethers.getContractFactory("Mock1InchExecutor");
        const Mock1InchRouter = await ethers.getContractFactory("Mock1InchRouter");

        args = [_ESE.address]
        const mock1InchExecutor = await Mock1InchExecutor.deploy(...args);
        await verify(mock1InchExecutor, args, "contracts/test/Mock1InchExecutor.sol:Mock1InchExecutor")

        const mock1InchRouter = await Mock1InchRouter.deploy();
        await verify(mock1InchRouter, [], "contracts/test/Mock1InchRouter.sol:Mock1InchRouter")

        await _ESE.transfer(mock1InchExecutor.address, '1000000000000000000000000')

        args = [
            _ESE.address, 
            _minter.address,
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', 
            '0xEF770dFb6D5620977213f55f99bfd781D04BBE15',//royaltyEngine
            '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',//vrfCoordinator
            '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',//ChainLink token
            '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',//150 gwei hash
            3,//minimumRequestConfirmations
            50000,//callbackGasLimit
            mock1InchRouter.address
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
            50000,//callbackGasLimit
            '0x1111111254eeb25477b68fb85ed929f73a960582'
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
            50000,//callbackGasLimit
            '0x1111111254eeb25477b68fb85ed929f73a960582'
        ]
    }else{
        return
    }

    _eesee = await eesee.deploy(...args)
    await verify(_eesee, args, "contracts/eesee.sol:eesee")

    console.log(`eesee: ${_eesee.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
