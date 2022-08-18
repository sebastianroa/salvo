// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Ownable.sol";

contract AddressRouter is Ownable {
    // Mapping addressName => address
    mapping(string => address) private addressDirectory;

    constructor() {
        /*
         *
         * Salvo
         *
         */
        addressDirectory[
            "Treasury"
        ] = 0xA49fdDA8E8d6e6199E040d73236f163184B40ae7;
        /*
         *
         * ERC20 Contracts
         *
         */
        addressDirectory["JOE"] = 0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd;
        addressDirectory["DAI"] = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
        addressDirectory["USDC"] = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
        addressDirectory["USDCE"] = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
        addressDirectory["WBTC"] = 0x50b7545627a5162F82A992c33b87aDc75187B218;
        addressDirectory["BTCB"] = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;
        addressDirectory["AVAX"] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        addressDirectory["VTX"] = 0x5817D4F0b62A59b17f75207DA1848C2cE75e7AF4;
        addressDirectory["PTP"] = 0x22d4002028f537599bE9f666d1c4Fa138522f9c8;
        addressDirectory["USDT"] = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
        addressDirectory["WETHE"] = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
        /*
         *
         * Staking Contract
         * Note: Vector Staking Contracts are also spenders
         *
         */
        addressDirectory[
            "DAIVectorSingle"
        ] = 0xC1ac7D1405b87259B8D380e0041d0573fb0AcB8c;
        addressDirectory[
            "USDCVectorSingle"
        ] = 0x994F0e36ceB953105D05897537BF55d201245156;
        addressDirectory[
            "WBTCEVectorSingle"
        ] = 0x5F334870A37516434ee2433a8c325fb7957661f9;
        addressDirectory[
            "BTCBVectorSingle"
        ] = 0xcA0EE0073EE80Ab1a82d266B081Fcde01BBE6c6A;
        addressDirectory[
            "AVAXVectorSingle"
        ] = 0xff5386aF93cF4bD8d5AeCad6df7F4f4be381fD69;
        addressDirectory[
            "BTCBAVAXVector"
        ] = 0x473bD859797F781d1626B9c6f9B3065FF741E14C;
        /*
         *
         * Spender
         *
         * NOTE: TJ Router is Spender
         */
        addressDirectory[
            "VectorPtpSpender"
        ] = 0x8B3d9F0017FA369cD8C164D0Cc078bf4cA588aE5; //For Dai
        addressDirectory[
            "JoeRouterSpender"
        ] = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
        addressDirectory[
            "SwapRouterSpender"
        ] = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
        /*
         *
         * Router
         *
         */
        addressDirectory[
            "JoeRouter"
        ] = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
        /*
         *
         * Liquidity Pools
         *
         */
        addressDirectory[
            "BTCBAVAXTJ"
        ] = 0x2fD81391E30805Cc7F2Ec827013ce86dc591B806;

        addressDirectory[
            "WETHEAVAXTJ"
        ] = 0xFE15c2695F1F920da45C30AAE47d11dE51007AF9;
        addressDirectory[
            "USDTAVAXTJ"
        ] = 0xbb4646a764358ee93c2a9c4a147d5aDEd527ab73;
        addressDirectory[
            "VTXAVAXTJ"
        ] = 0x9EF0C12b787F90F59cBBE0b611B82D30CAB92929;
        /*
         *
         * Claim Manager
         * Note: Used for multiclaim
         *
         */
        addressDirectory[
            "VectorMasterChef"
        ] = 0x423D0FE33031aA4456a17b150804aA57fc157d97;
        /*
         *
         * LP Trackers for Helpers
         * Note: Claim Manager will reference these addresses to determine how
         * much you own of LP
         * Used for multiclaim function
         *
         */
        addressDirectory[
            "BTCAVAXVectorTracker"
        ] = 0xD5817AC3027B1958961903238b374EcD8a5537A8;
    }

    /*
     * @dev View Any Address By Inserting Name
     */
    function viewAddressDirectory(string memory _name)
        public
        view
        returns (address)
    {
        return addressDirectory[_name];
    }

    /*
     * @dev Edit Any Address By Inserting Name & New Name
     */
    function editAddressDirectory(string memory _name, address _newAddress)
        public
        onlyOwner
    {
        require(
            addressDirectory[_name] !=
                0x0000000000000000000000000000000000000000,
            "Name does not exist."
        );
        addressDirectory[_name] = _newAddress;
    }

    /*
     * @dev Add Any Address By Inserting Name
     */
    function addAddressDirectory(string memory _name, address _newAddress)
        public
        onlyOwner
    {
        require(bytes(_name).length > 0, "Name is empty.");
        require(
            _newAddress != 0x0000000000000000000000000000000000000000,
            "Invalid address."
        );
        addressDirectory[_name] = _newAddress;
    }
}
