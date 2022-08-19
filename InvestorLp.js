const { ethers } = require("hardhat");
const hre = require("hardhat");
const { expect } = require("chai");
const ERC20 = [
    {
        "constant": true,
        "inputs": [],
        "name": "name",
        "outputs": [
            {
                "name": "",
                "type": "string"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": false,
        "inputs": [
            {
                "name": "_spender",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "approve",
        "outputs": [
            {
                "name": "",
                "type": "bool"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "totalSupply",
        "outputs": [
            {
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": false,
        "inputs": [
            {
                "name": "_from",
                "type": "address"
            },
            {
                "name": "_to",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "transferFrom",
        "outputs": [
            {
                "name": "",
                "type": "bool"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "decimals",
        "outputs": [
            {
                "name": "",
                "type": "uint8"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [
            {
                "name": "_owner",
                "type": "address"
            }
        ],
        "name": "balanceOf",
        "outputs": [
            {
                "name": "balance",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [],
        "name": "symbol",
        "outputs": [
            {
                "name": "",
                "type": "string"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "constant": false,
        "inputs": [
            {
                "name": "_to",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "transfer",
        "outputs": [
            {
                "name": "",
                "type": "bool"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "constant": true,
        "inputs": [
            {
                "name": "_owner",
                "type": "address"
            },
            {
                "name": "_spender",
                "type": "address"
            }
        ],
        "name": "allowance",
        "outputs": [
            {
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    {
        "payable": true,
        "stateMutability": "payable",
        "type": "fallback"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "name": "owner",
                "type": "address"
            },
            {
                "indexed": true,
                "name": "spender",
                "type": "address"
            },
            {
                "indexed": false,
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "Approval",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "name": "from",
                "type": "address"
            },
            {
                "indexed": true,
                "name": "to",
                "type": "address"
            },
            {
                "indexed": false,
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "Transfer",
        "type": "event"
    }
]

const avaxPrice = 16.64;
const btcPrice = 20000;
const ethPrice = 1201;
const bnbPrice = 220.2;
const usdPrice = 1.001;

const seekError = (errObj) => {
    //1. INSERT AN OPCODE
    const raiseSlippage = "RAISE_SLIPPAGE";
    const raiseGasLimit = "RAISE_GAS_LIMIT";
    //2. INSERT NEW ERROR MESSAGE
    //TJ
    const TJError1 = "Error: VM Exception while processing transaction: reverted with reason string 'JoeRouter: INSUFFICIENT_OUTPUT_AMOUNT'";
    //GENERAL
    const GAS_LIMIT = "UNPREDICTABLE_GAS_LIMIT";
    //3. ADD OPCODE + ERROR MESSAGE
    const errorLib = {
        TJError1: raiseSlippage,
        GAS_LIMIT: raiseGasLimit,

    }

    //ADD LIB FUNCTIONALITY TO DIRECTORY
    if (errObj.hasOwnProperty("data")) {
        if (errObj["data"].hasOwnProperty("message")) {
            if (errObj["data"]["message"] == TJError1) {
                return raiseSlippage;
            }
            //Perform An Action
            console.log("ErrorLib Msg: message does exist");
        }
    }
    if (errObj.hasOwnProperty("code")) {
        console.log(GAS_LIMIT);
        if (errObj["code"] == GAS_LIMIT) {
            //Perform An Action
            return raiseGasLimit;
        }
    }
}
const decimalCount = num => {
    // Convert to String
    const numStr = String(num);
    // String Contains Decimal
    if (numStr.includes('.')) {
        return numStr.split('.')[1].length;
    };
    // String Does Not Contain Decimal
    return 0;
}
const wholeConverter = num => {
    // Convert to String
    const numStr = String(num);
    if (numStr.includes('.')) {
        let joined = numStr.split('.')[0] + numStr.split('.')[1];
        return joined;
    } else {
        return numStr;
    }
}
//Convert human integer to crypto format
const packageInt = (num, decimals) => {
    if (typeof num !== 'string' && !isNaN(decimals) && num !== 0) {
        const numDecimals = decimalCount(num);
        let leftOverDecimals = 0; //For Small Quantities like 0.005 BTC
        let excessDecimals = 0; //Decimals exceeding standard
        if (numDecimals <= decimals) {
            leftOverDecimals = decimals - numDecimals;
        } else {
            excessDecimals = numDecimals - decimals;
        }
        const paddedZeroes = "0".repeat(leftOverDecimals);
        if (excessDecimals) {
            let numStr = Number(wholeConverter(num)).toString();
            return numStr.slice(0, numStr.length - excessDecimals);
        } else {
            const joinedIntegers = Number(wholeConverter(num)).toString();
            return joinedIntegers + paddedZeroes;
        }
    } else {
        throw new Error('Fields not completed.');
    }
}
//Convert crypto format to human integer
const unpackageInt = (num, decimals) => {
    //Returns human-readable integer rounded to two decimal places
    let numStr = num.toString();
    if (numStr.length > decimals) {
        let beforeDecimal = numStr.slice(0, numStr.length - decimals);
        let afterDecimal = numStr.slice(numStr.length - decimals, numStr.length);
        let adjustedNum = beforeDecimal + "." + afterDecimal;
        return Number(adjustedNum).toFixed(2);
    } else {
        let numZeroes = decimals - numStr.length;
        const zeroes = "0".repeat(numZeroes);
        let adjustedNum = "." + zeroes + numStr;
        return Number(adjustedNum).toFixed(2);
    }
}
const cryptoPairConversion = (cryptoPrice1, cryptoAmount1, cryptoPrice2) => (cryptoPrice1 * cryptoAmount1) / cryptoPrice2;
const applyAutoSlippage = (percentAsDecimal, num) => (num / (1 + percentAsDecimal)).toFixed(0);


describe("Staking Certificate Operation: Deploying liquidity to Vector", async function () {
    let provider = "";
    let url = "";
    let JContract = "";
    let VContract = "";
    let LPContract = "";
    let SMContract = "";
    let signer; let Bob; let Sally; let Dick; let Andy;
    let Sebastian; let David; let Julian;
    //ATTENTION - CHANGE VARIABLES BELOW TO TEST DIFFERENT LP PAIRS
    let purchaseToken = "USDC";
    let token1 = "BTCB";
    let token2 = "AVAX";
    let liquidityPool = "0x2fD81391E30805Cc7F2Ec827013ce86dc591B806"; //BTCBAVAX
    //Codes From AddressDirectory
    let spenderCode = "BTCBAVAXVector";
    let investmentContract = "0x473bD859797F781d1626B9c6f9B3065FF741E14C";
    let tokensToBeRewarded = [
        "0x5817D4F0b62A59b17f75207DA1848C2cE75e7AF4",
        "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd",
        "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"
    ];



    beforeEach(async () => {
        /**
         * 
         * 
         * Wallets + Contract Factories
         * 
         * 
         * */
        url = "http://127.0.0.1:8545/";
        provider = new ethers.providers.JsonRpcProvider(url);
        //Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        signer = new ethers.Wallet(
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
            provider
        );
        //Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
        Bob = new ethers.Wallet(
            "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
            provider
        );
        //Address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
        Sally = new ethers.Wallet(
            "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
            provider
        );
        //Address: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
        Dick = new ethers.Wallet(
            "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
            provider
        );
        //Address: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
        Andy = new ethers.Wallet(
            "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
            provider
        )
        //Impersonating Affiliates
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x320F23780c98f1cbA153dA685e67c4F02aC78bd1"],
        });



        /*
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x279f8940ca2a44C35ca3eDf7d28945254d0F0aE6"],
        });
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0xf1018f794E5A281889e74A873Af0d5C3373e55AD"],
        });
        */

        this.admin = await ethers.getSigner("0x320F23780c98f1cbA153dA685e67c4F02aC78bd1");


        Sebastian = "0x320F23780c98f1cbA153dA685e67c4F02aC78bd1";
        David = "0xf1018f794E5A281889e74A873Af0d5C3373e55AD";
        Julian = "0x47078678017ED661e7f6157d559a53a66DED7250";
        //Initialize Address Router
        const addressRouter = await ethers.getContractFactory("AddressRouter");
        addressRouterContract = await addressRouter.deploy();

        //Initialize Vector/Joe/Investor Helper Contracts
        const I = await ethers.getContractFactory("InvestorHelper");
        IContract = await I.deploy(_addressRouter = addressRouterContract.address);
        const J = await ethers.getContractFactory("JoeHelper");
        JContract = await J.deploy(_addressRouter = addressRouterContract.address);
        const V = await ethers.getContractFactory("VectorHelper");
        VContract = await V.deploy(_addressRouter = addressRouterContract.address);
        const SM = await ethers.getContractFactory("StakingManager");
        SMContract = await SM.deploy();

        const LP = await ethers.getContractFactory("InvestorLp");

        LPContract = await LP.deploy(
            _helper = VContract.address, //Gtg
            _swap = JContract.address, //Gtg
            _targetToken = ["0x152b9d0FdC40C096757F570A51E494bd4b943E50", "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"], //Gtg  ["0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664", "0xf2f13f0b7008ab2fa4a2418f4ccc3684e49d20eb"]
            _addressRouter = addressRouterContract.address, //Gtg
            _stakingManager = SMContract.address,
            _investmentAddress = investmentContract, //Gtg
            _liquidityPool = liquidityPool, //gtg BTCBAVAX "0xc0294fafdee273f4d8d01db52cc0c65102bc081f"
            _tokensToBeRewardedAddress = tokensToBeRewarded,
            _tokensToBeRewardedName = ["VTX", "JOE", "WAVAX"],
            _investorHelper = IContract.address,
            _poolId = 0
        );
        //Make the LP Contract Whitelisted on Staking Manager
        await SMContract.addWhitelistedContract(LPContract.address);
        await SMContract.createPool("0x2fD81391E30805Cc7F2Ec827013ce86dc591B806");
        await SMContract.addPartner("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"); // Signer
        await SMContract.addPartner(David);
        await SMContract.addPartner(David);
        await SMContract.addPartner(Julian);
        await SMContract.addPartnerReferral(David, Julian);
        await SMContract.addClient(Bob.address, David);

    });

    it("Conduct Deposit & Withdraw Operations", async function () {

        /**
        * @dev Swap USDC for Target Token Pair
        */
        // Load ERC20 Contracts
        const usdcAddress = await addressRouterContract.viewAddressDirectory(purchaseToken); // Note, mass load these on a hook
        const treasuryAddress = await addressRouterContract.viewAddressDirectory("Treasury"); // Note, mass load these on a hook
        const token1Address = await addressRouterContract.viewAddressDirectory(token1);
        const token2Address = await addressRouterContract.viewAddressDirectory(token2);
        const joeAddress = await addressRouterContract.viewAddressDirectory("JOE");
        const withdrawSpenderAddress = await addressRouterContract.viewAddressDirectory(spenderCode);
        const usdcContract = await hre.ethers.getContractAt("ERC20", usdcAddress);
        const token1Contract = await hre.ethers.getContractAt("ERC20", token1Address);
        const token2Contract = await hre.ethers.getContractAt("ERC20", token2Address);
        const joeContract = await hre.ethers.getContractAt("ERC20", joeAddress);
        const poolContract = await hre.ethers.getContractAt("ERC20", liquidityPool);

        /*
        *
        * 1. Master Deposit
        * 
        */
        const lp0 = await VContract.viewInvestmentBalance(investmentContract, LPContract.address);
        console.log("Begin Deposit---------");
        await LPContract.connect(Bob).routerDepositAvaxLp(token1, spenderCode,
            {
                gasLimit: 2000000,
                value: "5000000000000000000",
            });
        const lp1 = await VContract.viewInvestmentBalance(investmentContract, LPContract.address);
        const lpDiff = lp1 - lp0;
        const bobStaking = await SMContract.poolStakers("0", Bob.address);
        /* 
        * TEST: Check if LP tokens deposited into Vector, IF FAIL:
        * 1. Swap didn't get pair 1 token with AVAX
        * 2. Adding Liquidity did not work - the pair must not be 50/50
        */
        expect(lpDiff).to.not.equal(0);
        /* 
        * TEST: Depositor Credited on Staking Manager:
        * 1. Make sure the reward param in deposit is fed
        * 2. Error in the staking manager deposit function
        */
        expect(lpDiff).to.equal(bobStaking.amount);
        /* 
        *
        * 2. Accelerate Time For Reward Accumulation
        *
        */
        await ethers.provider.send("evm_increaseTime", [80600]);
        await ethers.provider.send("evm_mine", []); await ethers.provider.send("evm_mine", []); await ethers.provider.send("evm_mine", []);

        const btcBal0 = await token1Contract.balanceOf(LPContract.address);
        const avaxBal0 = await provider.getBalance(LPContract.address);
        console.log("Smart Contract Balances: BTC: ", btcBal0, " AVAX: ", avaxBal0);
        const dStake = await SMContract.poolStakers(0, David); const davidStake0 = Number(dStake.amount) + Number(dStake.rewards);
        const jStake = await SMContract.poolStakers(0, Julian); const juliStake0 = Number(jStake.amount) + Number(jStake.rewards);
        /*
        *
        * 3. Master Withdrawal
        * 
        */
        const testWithdrawalAmount = 61155263;
        const treasuryJoe0 = await joeContract.balanceOf(treasuryAddress);
        console.log("Begin Withdrawal----");
        await LPContract.connect(Bob).routerWithdraw(testWithdrawalAmount, withdrawSpenderAddress, { gasLimit: 29000000 });
        const treasuryJoe1 = await joeContract.balanceOf(treasuryAddress);
        console.log("Treasury & Partners Received----");
        expect(treasuryJoe1 - treasuryJoe0).to.not.equal(0);
        /* 
        * TEST: Assure Treasury Receives JOE:
        * 1. Transfer function in loop (See Comment 4. Investor LP)
        *   
        */
        const bobStaking1 = await SMContract.poolStakers("0", Bob.address);
        const dStake0 = await SMContract.poolStakers(0, David); const davidStake1 = Number(dStake0.amount) + Number(dStake0.rewards);
        const jStake0 = await SMContract.poolStakers(0, Julian); const juliStake1 = Number(jStake0.amount) + Number(jStake0.rewards);
        console.log("David: ", davidStake0, davidStake1);
        console.log("Julian: ", juliStake0, juliStake1);
        console.log("Bob: ", bobStaking.amount, bobStaking.rewards, bobStaking1.amount, bobStaking1.rewards);


    });

})
