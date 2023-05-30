// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { network, run, ethers } = require("hardhat");
const { getContractAddress } = require('@ethersproject/address')
function delay(time) {
  return new Promise(resolve => setTimeout(resolve, time));
}
async function main() {
    const ESE = await ethers.getContractFactory("ESE");
    const minter = await ethers.getContractFactory("eeseeMinter");
    const pool = await ethers.getContractFactory("eeseePool");
    const eesee = await ethers.getContractFactory("eesee");
    const mockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    const eeseeRandomETH = await ethers.getContractFactory("eeseeRandomETH");

    let args
    args = ['1000000000000000000000000000']
    const _ESE = await ESE.deploy(...args)
    await _ESE.deployTransaction.wait(1);
    console.log(1)
    /*await run("verify:verify", {
        address: _ESE.address,
        constructorArguments: args,
        contract: "contracts/ESE.sol:ESE"
    })*/

    args = ['','']//TODO
    const _minter = await minter.deploy(...args)
    await _minter.deployTransaction.wait(1);
    console.log(2)
    /*await run("verify:verify", {
        address: _minter.address,
        constructorArguments: args
    })*/
    
    //args = [_ESE.address]
    //const _pool = await pool.deploy(...args)
    //await _pool.deployTransaction.wait(5)
    /*await run("verify:verify", {
        address: _pool.address,
        constructorArguments: args
    })*/

    let _eesee
    let polygonWallet
    let futureAddress
    let __mockPriceOracle
    if(network.name === 'goerli'){
        //goerli testnet
        //init mumbai provider
        const polygonProvider = new ethers.providers.JsonRpcProvider('https://matic-mumbai.chainstacklabs.com')
        polygonWallet = new ethers.Wallet(process.env.PRIVATE_KEY, polygonProvider)

        //get MATIC/ETH price from polygon & set to mumbai
        const _polygonProvider = new ethers.providers.JsonRpcProvider('https://polygon-rpc.com/')
        const _wallet = new ethers.Wallet(process.env.PRIVATE_KEY, _polygonProvider)
        const _contractInstance = await ethers.getContractAt("contracts/test/MockPriceOracle.sol:MockPriceOracle", '0x327e23A4855b6F663a28c5161541d69Af8973302', _wallet);
        const _price = await _contractInstance.latestAnswer()
        const _decimals = await _contractInstance.decimals()
        __mockPriceOracle = await mockPriceOracle.connect(polygonWallet).deploy(_price, _decimals)
        await __mockPriceOracle.deployTransaction.wait(1);
        console.log(3)

        //get eeseeRandomETH address
        const transactionCount = await polygonProvider.getTransactionCount(polygonWallet.address);
        futureAddress = getContractAddress({
            from: polygonWallet.address,
            nonce: transactionCount
        })

        //get price from ETH an set to goerli
        const provider = new ethers.providers.JsonRpcProvider(process.env.ETHEREUMRPC)
        const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider)
        const contractInstance = await ethers.getContractAt("contracts/test/MockPriceOracle.sol:MockPriceOracle", '0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676', wallet);
        const price = await contractInstance.latestAnswer() 
        const decimals = await contractInstance.decimals() 
        const _mockPriceOracle = await mockPriceOracle.deploy(price, decimals)
        await _mockPriceOracle.deployTransaction.wait(1);
        console.log(4)

        args = [
            _ESE.address, 
            _minter.address,
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', //TODO
            '0xEF770dFb6D5620977213f55f99bfd781D04BBE15',//royaltyEngine
            '0xe432150cce91c13a887f7D836923d5597adD8E31',//Gateway Contract:
            '0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6',//gas service
            'Polygon',
            futureAddress,
            _mockPriceOracle.address,//_priceFeed_MATIC_USD
            '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e'//_priceFeed_ETH_USD
        ]
    } else if(network.name === 'ethereum') {
        //mainnet
        const polygonProvider = new ethers.providers.JsonRpcProvider('https://polygon-rpc.com/')
        polygonWallet = new ethers.Wallet(process.env.PRIVATE_KEY, polygonProvider)
        const transactionCount = await polygonProvider.getTransactionCount(polygonWallet.address);
        futureAddress = getContractAddress({
            from: polygonWallet.address,
            nonce: transactionCount
        })

        args = [
            _ESE.address, 
            _minter.address,
            '0xEa6E311c2365F67218EFdf19C6f24296cdBF0058', //TODO
            '0x0385603ab55642cb4Dd5De3aE9e306809991804f',//royaltyEngine
            '0x4F4495243837681061C4743b74B3eEdf548D56A5',//Gateway Contract:
            '0x2d5d7d31F671F86C782533cc367F14109a082712',//gas service
            'Polygon',
            futureAddress,
            '0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676',//_priceFeed_MATIC_USD
            '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'//_priceFeed_ETH_USD
        ]
    }else{
        return
    }
    //POLYGON will be used in the future but the contracts will be different
    /*else if(network.name === 'polygon'){
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
    }*/

    _eesee = await eesee.deploy(...args)
    await _eesee.deployTransaction.wait(1);
    /*console.log(5)
    await run("verify:verify", {
        address: _eesee.address,
        constructorArguments: args,
    })
    console.log(555)*/
    const [owner] = await ethers.getSigners();
        //transfer costs more because it calls receive()
    await owner.sendTransaction({
        to: _eesee.address,
        value: ethers.utils.parseEther('0.05', 'ether'),
        gasLimit: 50000
    });

    if(network.name === 'goerli'){
        args = [
            '0xBF62ef1486468a6bd26Dd669C06db43dEd5B849B',//_gateway
            '0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6',//_gasService
            'ethereum-2',
            _eesee.address,
            __mockPriceOracle.address,//_priceFeed_MATIC_ETH
            '0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed',//vrfCoordinator
            '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',//ChainLink token
            '0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f',//500 gwei hash
            13,//minimumRequestConfirmations
            170000//callbackGasLimit
        ]
    }else if(network.name === 'ethereum'){
        args = [
            '0x6f015F16De9fC8791b234eF68D486d2bF203FBA8',//_gateway
            '0x2d5d7d31F671F86C782533cc367F14109a082712',//_gasService
            'Ethereum',
            _eesee.address,
            '0x327e23A4855b6F663a28c5161541d69Af8973302',//_priceFeed_MATIC_ETH
            '0xAE975071Be8F8eE67addBC1A82488F1C24858067',//vrfCoordinator
            '0xb0897686c545045aFc77CF20eC7A532E3120E0F1',//ChainLink token
            '0xcc294a196eeeb44da2888d17c0625cc88d70d9760a69d58d853ba6581a9ab0cd',//500 gwei hash
            13,//minimumRequestConfirmations
            170000//callbackGasLimit
        ]
    }
    const _eeseeRandomETH = await eeseeRandomETH.connect(polygonWallet).deploy(...args)
    await _eeseeRandomETH.deployTransaction.wait(1);
    console.log(6)
    if(network.name === 'goerli'){
        await polygonWallet.sendTransaction({
            to: _eeseeRandomETH.address,
            value: ethers.utils.parseEther('100', 'ether')
        });
        console.log(7)

        const chainlinkToken = await ethers.getContractAt("contracts/ESE.sol:ESE", '0x326C977E6efc84E512bB9C30f76E30c160eD06FB', polygonWallet);
        let tx = await chainlinkToken.connect(polygonWallet).approve(_eeseeRandomETH.address, ethers.utils.parseEther('2', 'ether'))
        await tx.wait(1)
        console.log(8)

        tx = await _eeseeRandomETH.connect(polygonWallet).fund(ethers.utils.parseEther('2', 'ether'))
        await tx.wait(1)
        console.log(9)

        tx = await _eesee.mintAndListItem('', 2, 100, 100000, owner.address, 100)
        await tx.wait(1)
        console.log(10)

        tx = await _ESE.approve(_eesee.address, ethers.utils.parseEther('1', 'ether'))
        await tx.wait(1)
        console.log(11)

        tx = await _eesee.buyTickets(1,1)
        await tx.wait(1)
        console.log(12)

        const wallet = new ethers.Wallet(process.env.PRIVATE_KEY2, ethers.provider)
        tx = await _ESE.transfer(wallet.address, ethers.utils.parseEther('1', 'ether'))
        await tx.wait(1)
        console.log(13)

        tx = await _ESE.connect(wallet).approve(_eesee.address, ethers.utils.parseEther('1', 'ether'))
        await tx.wait(1)
        console.log(14)

        tx = await _eesee.connect(wallet).buyTickets(1, 1)
        await tx.wait(1)
        console.log(15)
    }

    console.log(`eesee: ${_eesee.address}`)
    console.log(`eeseeRandomETH: ${_eeseeRandomETH.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
