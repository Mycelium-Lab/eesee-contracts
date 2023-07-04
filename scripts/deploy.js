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
    const [signer] = await ethers.getSigners();
    const ESE = await ethers.getContractFactory("ESE");
    const minter = await ethers.getContractFactory("eeseeMinter");
    const pool = await ethers.getContractFactory("eeseeMining");
    const eesee = await ethers.getContractFactory("eesee");
    const staking = await ethers.getContractFactory("eeseeStaking");
    const feeSplitter = await ethers.getContractFactory("eeseeFeeSplitter");
    const Mock1InchExecutor = await ethers.getContractFactory("Mock1InchExecutor");
    const Mock1InchRouter = await ethers.getContractFactory("Mock1InchRouter");

    let args

    let mock1InchRouter
    let mock1InchExecutor
    if(network.name === 'goerli'){
        const transactionCount = await signer.getTransactionCount()
        const futureESE = getContractAddress({
            from: signer.address,
            nonce: transactionCount + 2
        })
        //goerli testnet
        args = [futureESE]
        mock1InchExecutor = await Mock1InchExecutor.deploy(...args);
        await verify(mock1InchExecutor, args, "contracts/test/Mock1InchExecutor.sol:Mock1InchExecutor")

        mock1InchRouter = await Mock1InchRouter.deploy();
        await verify(mock1InchRouter, [], "contracts/test/Mock1InchRouter.sol:Mock1InchRouter")
    }

    const transactionCount = await signer.getTransactionCount()
    const futureMining = getContractAddress({
        from: signer.address,
        nonce: transactionCount + 1
    })
    const futureStaking = getContractAddress({
        from: signer.address,
        nonce: transactionCount + 4
    })
    const futureFeeSplitter = getContractAddress({
        from: signer.address,
        nonce: transactionCount + 5
    })

    let month = 60*60*24*365/12
    args = [
        [{//presale
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
            beneficiaries: [{addr: futureMining, amount: '450000000000000000000000000'}]
        },
        {//marketing and partnerships
            cliff: month*6,
            duration: month*36,
            TGEMintShare: 0,
            beneficiaries: []
        },
        {//staking
            cliff: 0,
            duration: month*36,
            TGEMintShare: 0,
            beneficiaries: [{addr:futureStaking, amount: '80000000000000000000000000'}]
        }]
    ]
    const _ESE = await ESE.deploy(...args)//0
    await verify(_ESE, args, "contracts/ESE.sol:ESE")
    
    args = [_ESE.address]
    const _pool = await pool.deploy(...args)//1
    await verify(_pool, args, "contracts/eeseeMining.sol:eeseeMining")

    args = ['','']//TODO
    const _minter = await minter.deploy(...args)//2
    await verify(_minter, args, "contracts/NFT/eeseeMinter.sol:eeseeMinter")

    let _eesee
    if(network.name === 'goerli'){
        args = [
            _ESE.address, 
            futureStaking,
            _minter.address,
            futureFeeSplitter, 
            '0xEF770dFb6D5620977213f55f99bfd781D04BBE15',//royaltyEngine
            {
                vrfCoordinator: '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',//vrfCoordinator
                LINK: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',//ChainLink token
                keyHash: '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',//150 gwei hash
                keyHashGasLane: 150000000000,
                minimumRequestConfirmations: 3,//minimumRequestConfirmations
                callbackGasLimit: 50000,//callbackGasLimit
                LINK_ETH_DataFeed: '0xb4c4a493AB6356497713A78FFA6c60FB53517c63'
            },
            '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',//WETH
            '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',//uinswapRouter
            mock1InchRouter.address
        ]
    }else if(network.name === 'ethereum'){
        args = [
            _ESE.address, 
            futureStaking,
            _minter.address,
            futureFeeSplitter,
            '0x0385603ab55642cb4Dd5De3aE9e306809991804f',//royaltyEngine
            {
                vrfCoordinator:'0x271682DEB8C4E0901D1a1550aD2e64D568E69909',//vrfCoordinator
                LINK: '0x514910771AF9Ca656af840dff83E8264EcF986CA',//ChainLink token
                keyHash: '0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef',//200 gwei hash
                keyHashGasLane: 200000000000,
                minimumRequestConfirmations: 13,//minimumRequestConfirmations
                callbackGasLimit: 50000,//callbackGasLimit
                LINK_ETH_DataFeed: '0xdc530d9457755926550b59e8eccdae7624181557'
            },
            '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',//weth
            '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',//uinswapRouter
            '0x1111111254eeb25477b68fb85ed929f73a960582'//oneInch
        ]
    }else if(network.name === 'polygon'){
        args = [
            _ESE.address, 
            futureStaking,
            _minter.address, 
            futureFeeSplitter,
            '0x28EdFcF0Be7E86b07493466e7631a213bDe8eEF2',//royaltyEngine
            {
                vrfCoordinator:'0xAE975071Be8F8eE67addBC1A82488F1C24858067',//vrfCoordinator
                LINK: '0xb0897686c545045aFc77CF20eC7A532E3120E0F1',//ChainLink token
                keyHash: '0x6e099d640cde6de9d40ac749b4b594126b0169747122711109c9985d47751f93',//200 gwei hash
                keyHashGasLane: 200000000000,
                minimumRequestConfirmations: 13,//minimumRequestConfirmations
                callbackGasLimit: 50000,//callbackGasLimit
                LINK_ETH_DataFeed: '0x5787BefDc0ECd210Dfa948264631CD53E68F7802'
            },
            '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270',//weth
            '0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff',//quickswapRouter
            '0x1111111254eeb25477b68fb85ed929f73a960582'
        ]
    }else{
        return
    }

    _eesee = await eesee.deploy(...args)//3
    await verify(_eesee, args, "contracts/eesee.sol:eesee")

    args = [
        _ESE.address, 
        _eesee.address,
        [
            {volumeBreakpoint: ethers.utils.parseEther('100'), rewardRateFlexible: ethers.utils.parseEther((0.12/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.18/31536000).toFixed(18))},//1
            {volumeBreakpoint: ethers.utils.parseEther('250'), rewardRateFlexible: ethers.utils.parseEther((0.13/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.19/31536000).toFixed(18))},//2
            {volumeBreakpoint: ethers.utils.parseEther('500'), rewardRateFlexible: ethers.utils.parseEther((0.14/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.20/31536000).toFixed(18))},//3
            {volumeBreakpoint: ethers.utils.parseEther('1000'), rewardRateFlexible: ethers.utils.parseEther((0.15/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.22/31536000).toFixed(18))},//4
            {volumeBreakpoint: ethers.utils.parseEther('2000'), rewardRateFlexible: ethers.utils.parseEther((0.16/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.24/31536000).toFixed(18))},//5
            {volumeBreakpoint: ethers.utils.parseEther('6000'), rewardRateFlexible: ethers.utils.parseEther((0.18/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.26/31536000).toFixed(18))},//6
            {volumeBreakpoint: ethers.utils.parseEther('15000'), rewardRateFlexible: ethers.utils.parseEther((0.20/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.28/31536000).toFixed(18))},//7
            {volumeBreakpoint: ethers.utils.parseEther('40000'), rewardRateFlexible: ethers.utils.parseEther((0.22/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.30/31536000).toFixed(18))},//8
            {volumeBreakpoint: ethers.utils.parseEther('100000'), rewardRateFlexible: ethers.utils.parseEther((0.24/31536000).toFixed(18)), rewardRateLocked: ethers.utils.parseEther((0.32/31536000).toFixed(18))},//9
            //ignores breakpoint for last one
            {volumeBreakpoint: '0', rewardRateFlexible:ethers.utils.parseEther((0.26/31536000).toFixed(18)), rewardRateLocked:ethers.utils.parseEther((0.35/31536000).toFixed(18))}//10
        ]
    ]

    let _staking = await staking.deploy(...args)//4
    await verify(_staking, args, "contracts/eeseeStaking.sol:eeseeStaking")

    args = [
        _ESE.address, 
        {addr: '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', share: ethers.utils.parseEther('0.5')},//company //TODO:
        {addr: _pool.address, share: ethers.utils.parseEther('0.3')},//mining
        {addr: '0xA7b7DDF752Ed3A9785F747a3694760bB8994e15F', share:ethers.utils.parseEther('0.1')},//dao//TODO:
        {addr: _staking.address, share:ethers.utils.parseEther('0.1')}//stakingPool
    ]
    let _feeSplitter = await feeSplitter.deploy(...args)//5
    await verify(_feeSplitter, args, "contracts/eeseeFeeSplitter.sol:eeseeFeeSplitter")

    if(network.name === 'goerli'){
        await _ESE.transfer(mock1InchExecutor.address, '1000000000000000000000000')
    }

    console.log(`eesee: ${_eesee.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
