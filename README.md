# salvo

The contract works off a similar concept to the diamond pattern (see https://eips.ethereum.org/EIPS/eip-2535).
The main contract is InvestorLp.sol. This is the contract that interacts with EOAs on dApp. 
InvestorLp performs delegate calls to the the following contracts:
1. StakingManager.sol which manages who is owed rewards and balances. 
2. JoeHelper.sol contains interface calls to the Trader Joe Router on Avalanche.
3. VectorHelper.sol contains interface calls to the Vector Finance Staking contracts.
4. AddressRouter.sol contains universal addresses that can be called by any contract (ex. address for WAVAX or USDC)
5. InvestorHelper.sol serves an extension of InvestorLP that can be reached as a delegatecall. 

Notes:
Staking Manager has forked code from MasterChef but personalized implemented code to accomodate the protocol's commission structure to salespeople. 
JoeHelper & VectorHelper purely conduct external calls to the aforementioned 3rd party contracts.
InvestorHelper will have the same storage slot variables as InvestorLP to prevent corruption of data between calls. 
