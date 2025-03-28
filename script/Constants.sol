// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {CommonBase} from "forge-std/Base.sol";

contract Constants is CommonBase {
    string constant ethereum = "ethereum";
    string constant sepolia = "sepolia";
    string constant arbitrum = "arbitrum";
    string constant arbitrum_nova = "arbitrum_nova";
    string constant arbitrum_sepolia = "arbitrum_sepolia";
    string constant optimism = "optimism";
    string constant optimism_sepolia = "optimism_sepolia";
    string constant base = "base";
    string constant base_sepolia = "base_sepolia";
    string constant zora = "zora";
    string constant zora_sepolia = "zora_sepolia";
    string constant polygon = "polygon";
    string constant polygon_amoy = "polygon_amoy";
    string constant avalanche = "avalanche";
    string constant avalanche_fuji = "avalanche_fuji";
    string constant fantom = "fantom";
    string constant fantom_testnet = "fantom_testnet";
    string constant moonbeam = "moonbeam";
    string constant moonbeam_testnet = "moonbeam_testnet";
    string constant rari = "rari";
    string constant rari_testnet = "rari_testnet";
    string constant mantle = "mantle";
    string constant mantle_sepolia = "mantle_sepolia";
    string constant mode = "mode";
    string constant mode_sepolia = "mode_sepolia";
    string constant zksync = "zksync";
    string constant zksync_sepolia = "zksync_sepolia";
    string constant bnb = "bnb";
    string constant bnb_testnet = "bnb_testnet";
    string constant opbnb = "opbnb";
    string constant opbnb_testnet = "opbnb_testnet";
    string constant degen = "degen";
    string constant cyber = "cyber";
    string constant cyber_testnet = "cyber_testnet";
    string constant blast = "blast";
    string constant scroll = "scroll";
    string constant gnosis = "gnosis";
    string constant ape = "ape";
    string constant ape_curtis = "ape_cur Curtis";
    string constant zero = "zero";
    string constant lisk = "lisk";
    string constant sanko = "sanko";
    string constant superposition = "superposition";
    string constant courage_asleep_southern = "courage_asleep_southern";
    string constant breeze_contain_secret = "breeze_contain_secret";
    string constant ink = "ink";
    string constant appchain = "appchain";
    string constant plume = "plume";
    string constant abstract_chain = "abstract";
    string constant berachain = "berachain";
    string constant unichain = "unichain";
    string constant soneium = "soneium";
    string constant glue = "glue";
    string constant story = "story";
    string constant lumia = "lumia";

    constructor() {
        _setupChainInfo();
        _setupLzV1ChainInfo();
        _setupLzV2ChainInfo();
        _setupSgChainInfo();
        _setupHyperlaneChainInfo();
        _loadAllUniRouterInfo();
    }

    mapping(string => bool) gasEthLookup;
    mapping(string => address) wethLookup;
    mapping(string => address) wrappedLookup;
    mapping(string => uint256) chainIdLookup;
    mapping(string => uint8) decimalsLookup;

    function _setupChainInfo() internal {
        address OP_STACK_WETH = 0x4200000000000000000000000000000000000006;

        // configureChain(chain, decimals, isGasEth, chainId, weth, wrapped);
        configureChain(ethereum, 18, true, 1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        configureChain(sepolia, 18, true, 11155111, 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
        configureChain(arbitrum, 18, true, 42161, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        configureChain(arbitrum_nova, 18, true, 42170, 0x722E8BdD2ce80A4422E880164f2079488e115365);
        configureChain(arbitrum_sepolia, 18, true, 421614, 0x0133Ff8B0eA9f22e510ff3A8B245aa863b2Eb13F);
        configureChain(optimism, 18, true, 10, OP_STACK_WETH);
        configureChain(optimism_sepolia, 18, true, 11155420, OP_STACK_WETH);
        configureChain(base, 18, true, 8453, OP_STACK_WETH);
        configureChain(base_sepolia, 18, true, 84532, OP_STACK_WETH);
        configureChain(zora, 18, true, 7777777, OP_STACK_WETH);
        configureChain(zora_sepolia, 18, true, 999999999, OP_STACK_WETH);
        configureChain(polygon, 18, false, 137, 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,  0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        configureChain(polygon_amoy, 18, false, 80002, 0x8154fC0b8601D781fd2D32B8099D0cE0eFe1dE18, 0x01805a841ece00cf680996bF4B4e21746C68Fd4e);
        configureChain(avalanche, 18, false, 43114, 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB, 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
        configureChain(fantom_testnet, 18, false, 4002, 0x84C7dD519Ea924bf1Cf6613f9127F26D7aB801D0, 0x07B9c47452C41e8E00f98aC4c075F5c443281d2A);
        configureChain(rari, 18, true, 1380012617, 0xf037540e51D71b2D2B1120e8432bA49F29EDFBD0);
        configureChain(rari_testnet, 18, true, 1918988905, 0x2c9Dd2b2cd55266e3b5c3C95840F3c037fbCb856);
        configureChain(mantle, 18, false, 5000, 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111, 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8);
        configureChain(mantle_sepolia, 18, false, 5003, 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111, 0xDC1f593f30F533b460F092cc2AcfbCA0715A4040);
        configureChain(mode, 18, true, 34443, OP_STACK_WETH);
        configureChain(mode_sepolia, 18, true, 919, 0x5CE359Ff65f8bc3c874c16Fa24A2c1fd26bB57CD);
        configureChain(zksync, 18, true, 324, 0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91);
        configureChain(bnb, 18, false, 56, 0x2170Ed0880ac9A755fd29B2688956BD959F933F8, 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        configureChain(opbnb, 18, false, 204, 0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea, 0x4200000000000000000000000000000000000006);
        configureChain(degen, 18, false, 666666666, 0xF058Eb3C946F0eaeCa3e6662300cb01165c64edE, 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387);
        configureChain(cyber, 18, true, 7560, OP_STACK_WETH);
        configureChain(blast, 18, true, 81457, 0x4300000000000000000000000000000000000004);
        configureChain(scroll, 18, true, 534352, 0x5300000000000000000000000000000000000004);
        configureChain(gnosis, 18, false, 100, 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        configureChain(ape, 18, false, 33139, 0x5214E5AbCAD452fbbeb324511B4b35ccaA6b04bA, 0x48b62137EdfA95a428D35C09E44256a739F6B557);
        configureChain(ape_curtis, 18, false, 33111, 0xFADE439686c620f81458FF85d7fF5A0FE2CdB41E, 0x8643A49363E80C7A15790703b915D1b0B6b71D56);
        configureChain(zero, 18, true, 543210, 0xAc98B49576B1C892ba6BFae08fE1BB0d80Cf599c);
        configureChain(lisk, 18, true, 1135, 0x4200000000000000000000000000000000000006);
        configureChain(sanko, 18, false, 1996, 0xE01e3b20C5819cf919F7f1a2b4C18bBfd222F376, 0x754cDAd6f5821077d6915004Be2cE05f93d176f8);
        configureChain(superposition, 18, true, 55244, 0x1fB719f10b56d7a85DCD32f27f897375fB21cfdd);
        configureChain(courage_asleep_southern, 18, true, 123420000941, 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        configureChain(breeze_contain_secret, 18, true, 123420000871, 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        configureChain(ink, 18, true, 57073, 0x4200000000000000000000000000000000000006);
        configureChain(appchain, 18, true, 466, 0x4Dc858482ddF1E4e07a3db6Ec28535B1c3fa993C);
        configureChain(plume, 18, true, 98865, 0x626613B473F7eF65747967017C11225436EFaEd7);
        configureChain(abstract_chain, 18, true, 2741, 0x3439153EB7AF838Ad19d56E1571FBD09333C2809);
        configureChain(berachain, 18, false, 80094, 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590, 0x6969696969696969696969696969696969696969);
        configureChain(unichain, 18, true, 130, 0x4200000000000000000000000000000000000006);
        configureChain(soneium, 18, true, 1868, 0x4200000000000000000000000000000000000006);
        configureChain(glue, 18, false, 1300, 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590, 0x9a1691D500C54e1d79df2347D170987aa3E527aC);
        configureChain(story, 18, false, 1514, 0xBAb93B7ad7fE8692A878B95a8e689423437cc500, 0x1514000000000000000000000000000000000000);
        configureChain(lumia, 18, false, 994873017, 0x5A77f1443D16ee5761d310e38b62f77f726bC71c, 0xE891B5EE2F52E312038710b761EC165792AD25B1);
    }

    function configureChain(
        string memory chain,
        uint8 decimals,
        bool isGasEth,
        uint256 chainId,
        address weth
    ) public {
        configureChain(chain, decimals, isGasEth, chainId, weth, weth);
    }

    function configureChain(
        string memory chain,
        uint8 decimals,
        bool isGasEth,
        uint256 chainId,
        address weth,
        address wrapped
    ) public {
        require(weth != address(0), string.concat('weth not set for chain: ', chain));
        require(wrapped != address(0), string.concat('wrapped not set for chain: ', chain));

        if (weth != wrapped) {
            require(!isGasEth, string.concat('isGasEth not set properly for chain: ', chain));
        } else {
            require(isGasEth, string.concat('isGasEth not set properly for chain: ', chain));
        }

        decimalsLookup[chain] = decimals;
        gasEthLookup[chain] = isGasEth;
        chainIdLookup[chain] = chainId;
        wethLookup[chain] = weth;
        wrappedLookup[chain] = wrapped;

        vm.label(weth, string.concat(chain, "_WETH"));
        vm.label(wrapped, string.concat(chain, "_WRAPPED"));
    }

    mapping(string => address) lzV1EndpointLookup;
    mapping(string => uint16) lzV1IdLookup;

    function _setupLzV1ChainInfo() internal {
        _configureLzV1Chain(ethereum, 101, 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);
        _configureLzV1Chain(sepolia, 10161, 0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1);
        _configureLzV1Chain(arbitrum, 110, 0x3c2269811836af69497E5F486A85D7316753cf62);
        _configureLzV1Chain(arbitrum_nova, 175, 0x4EE2F9B7cf3A68966c370F3eb2C16613d3235245);
        _configureLzV1Chain(arbitrum_sepolia, 10231, 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3);
        _configureLzV1Chain(optimism, 111, 0x3c2269811836af69497E5F486A85D7316753cf62);
        _configureLzV1Chain(optimism_sepolia, 10232, 0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8);
        _configureLzV1Chain(base, 184, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(base_sepolia, 10245, 0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8);
        _configureLzV1Chain(zora, 195, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(zora_sepolia, 10249, 0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8);
        _configureLzV1Chain(polygon, 109, 0x3c2269811836af69497E5F486A85D7316753cf62);
        _configureLzV1Chain(avalanche, 106, 0x3c2269811836af69497E5F486A85D7316753cf62);
        _configureLzV1Chain(avalanche_fuji, 10106, 0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706);
        _configureLzV1Chain(fantom, 112, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(fantom_testnet, 10112, 0x7dcAD72640F835B0FA36EFD3D6d3ec902C7E5acf);
        _configureLzV1Chain(moonbeam, 126, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4);
        _configureLzV1Chain(moonbeam_testnet, 10126,  0xb23b28012ee92E8dE39DEb57Af31722223034747);
        _configureLzV1Chain(rari, 235, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(rari_testnet, 10235, 0x83c73Da98cf733B03315aFa8758834b36a195b87);
        _configureLzV1Chain(mantle, 181, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(mantle_sepolia, 10246, 0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648);
        _configureLzV1Chain(mode, 260, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(mode_sepolia, 10260, 0x2cA20802fd1Fd9649bA8Aa7E50F0C82b479f35fe);
        _configureLzV1Chain(zksync, 165, 0x9b896c0e23220469C7AE69cb4BbAE391eAa4C8da);
        _configureLzV1Chain(bnb, 102, 0x3c2269811836af69497E5F486A85D7316753cf62);
        _configureLzV1Chain(opbnb, 202, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(degen, 267, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(cyber, 283, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(blast, 243, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(scroll, 214, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(gnosis, 145, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4);
        _configureLzV1Chain(lisk, 321, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(sanko, 278, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(superposition, 327, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(ink, 339, 0x6b383D6a7e5a151b189147F4c9f39bF57B29548f);
        _configureLzV1Chain(plume, 318, 0x626613B473F7eF65747967017C11225436EFaEd7);
        _configureLzV1Chain(abstract_chain, 324, 0x042b8289c97896529Ec2FE49ba1A8B9C956A86cC);
        _configureLzV1Chain(berachain, 362, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(unichain, 320, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
        _configureLzV1Chain(soneium, 340, 0xa34F3b68c503e04b1554Bf1C98616De99F1e459D);
        _configureLzV1Chain(glue, 342, 0xC1b15d3B262bEeC0e3565C11C9e0F6134BdaCB36);
        _configureLzV1Chain(story, 364, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);
    }

    function _configureLzV1Chain(
        string memory chain,
        uint16 lzV1Id,
        address lzV1Endpoint
    ) internal {
        lzV1IdLookup[chain] = lzV1Id;
        lzV1EndpointLookup[chain] = lzV1Endpoint;
        vm.label(lzV1Endpoint, string.concat("lz_v1_endpoint_", chain));
    }

    mapping(string => address) lzV2EndpointLookup;
    mapping(string => uint32) lzV2IdLookup;

    function _setupLzV2ChainInfo() internal {
        _configureLzV2Chain(ethereum, 30101, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(sepolia, 40161, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(arbitrum, 30110, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(arbitrum_nova, 30175, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(arbitrum_sepolia, 40231, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(optimism, 30111, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(optimism_sepolia, 40232, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(base, 30184, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(base_sepolia, 40245, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(zora, 30195, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(zora_sepolia, 40249, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(polygon, 30109, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(polygon_amoy, 40267, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(avalanche, 30106, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(avalanche_fuji, 40106, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(fantom, 30112, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(fantom_testnet, 40112, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(moonbeam, 30126, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(moonbeam_testnet, 40126,  0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(rari, 30235, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(rari_testnet, 40235, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(mantle, 30181, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(mantle_sepolia, 40246, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(mode, 30260, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(mode_sepolia, 40260, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(zksync, 30165, 0xd07C30aF3Ff30D96BDc9c6044958230Eb797DDBF);
        _configureLzV2Chain(zksync_sepolia, 40305, 0xe2Ef622A13e71D9Dd2BBd12cd4b27e1516FA8a09);
        _configureLzV2Chain(bnb, 30102, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(bnb_testnet, 40102, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(opbnb, 30202, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(opbnb_testnet, 40202, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(degen, 30267, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(cyber, 30283, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(cyber_testnet, 40280, 0x6EDCE65403992e310A62460808c4b910D972f10f);
        _configureLzV2Chain(blast, 30243, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(scroll, 30214, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(gnosis, 30145, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(ape, 30312, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(ape_curtis, 40306, 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff);
        _configureLzV2Chain(lisk, 30321, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(sanko, 30278, 0x1a44076050125825900e736c501f859c50fE728c);
        _configureLzV2Chain(superposition, 30327, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(ink, 30339, 0xca29f3A6f966Cb2fc0dE625F8f325c0C46dbE958);
        _configureLzV2Chain(plume, 30318, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(abstract_chain, 30324, 0x5c6cfF4b7C49805F8295Ff73C204ac83f3bC4AE7);
        _configureLzV2Chain(berachain, 30362, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(unichain, 30320, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        _configureLzV2Chain(soneium, 30340, 0x4bCb6A963a9563C33569D7A512D35754221F3A19);
        _configureLzV2Chain(glue, 30342, 0xcb566e3B6934Fa77258d68ea18E931fa75e1aaAa);
        _configureLzV2Chain(story, 30364, 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9);
    }

    function _configureLzV2Chain(
        string memory chain,
        uint32 lzV2Id,
        address lzV2Endpoint
    ) internal {
        lzV2IdLookup[chain] = lzV2Id;
        lzV2EndpointLookup[chain] = lzV2Endpoint;
        vm.label(lzV2Endpoint, string.concat("lz_v2_endpoint_", chain));
    }

    mapping(string => address) sgComposerLookup;
    mapping(string => address) sgFactoryLookup;
    mapping(string => address) sgEthLookup;

    function _setupSgChainInfo() internal {
        address STARGATE_COMMON_COMPOSER = 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9;

        _addComposer(ethereum, STARGATE_COMMON_COMPOSER);
        _addComposer(arbitrum, STARGATE_COMMON_COMPOSER);
        _addComposer(optimism, STARGATE_COMMON_COMPOSER);
        _addComposer(avalanche, STARGATE_COMMON_COMPOSER);
        _addComposer(polygon, STARGATE_COMMON_COMPOSER);
        _addComposer(fantom, STARGATE_COMMON_COMPOSER);
        _addComposer(base, STARGATE_COMMON_COMPOSER);
        _addComposer(mantle, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97);
        _addComposer(bnb, 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9);

        _addStargateEth(ethereum, 0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c);
        _addStargateEth(arbitrum, 0x82CbeCF39bEe528B5476FE6d1550af59a9dB6Fc0);
        _addStargateEth(optimism, 0xb69c8CBCD90A39D8D3d3ccf0a3E968511C3856A0);
        _addStargateEth(base, 0x224D8Fd7aB6AD4c6eb4611Ce56EF35Dec2277F03);

        _addStargateFactory(ethereum, 0x06D538690AF257Da524f25D0CD52fD85b1c2173E);
        _addStargateFactory(arbitrum, 0x55bDb4164D28FBaF0898e0eF14a589ac09Ac9970);
        _addStargateFactory(optimism, 0xE3B53AF74a4BF62Ae5511055290838050bf764Df);
        _addStargateFactory(avalanche, 0x808d7c71ad2ba3FA531b068a2417C63106BC0949);
        _addStargateFactory(polygon, 0x808d7c71ad2ba3FA531b068a2417C63106BC0949);
        _addStargateFactory(fantom, 0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944);
        _addStargateFactory(base, 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);
        _addStargateFactory(mantle, 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398);
        _addStargateFactory(bnb, 0xe7Ec689f432f29383f217e36e680B5C855051f25);
    }

    function _addComposer(string memory chain, address _address) private {
        sgComposerLookup[chain] = _address;
        vm.label(_address, string.concat("stargate_composer_", chain));
    }

    function _addStargateEth(string memory chain, address _address) private {
        sgEthLookup[chain] = _address;
        vm.label(_address, string.concat("stargate_eth_", chain));
    }

    function _addStargateFactory(string memory chain, address _address) private {
        sgFactoryLookup[chain] = _address;
        vm.label(_address, string.concat("stargate_factory_", chain));
    }

    mapping(string => address) public hyperlaneMailboxLookup;
    mapping(string => uint32) public hyperlaneDomainIdLookup;

    function _setupHyperlaneChainInfo() internal {
        _configureHypChain(abstract_chain, 2741, 0x9BbDf86b272d224323136E15594fdCe487F40ce7);
        _configureHypChain(ape, 33139, 0x7f50C5776722630a0024fAE05fDe8b47571D7B39);
        _configureHypChain(appchain, 466, 0x3a464f746D23Ab22155710f44dB16dcA53e0775E);
        _configureHypChain(arbitrum, 42161, 0x979Ca5202784112f4738403dBec5D0F3B9daabB9);
        _configureHypChain(arbitrum_nova, 42170, 0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7);
        _configureHypChain(arbitrum_sepolia, 421614, 0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8);
        _configureHypChain(avalanche, 43114, 0xFf06aFcaABaDDd1fb08371f9ccA15D73D51FeBD6);
        _configureHypChain(base, 8453, 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D);
        _configureHypChain(base_sepolia, 84532, 0x6966b0E55883d49BFB24539356a2f8A673E02039);
        _configureHypChain(berachain, 80094, 0x7f50C5776722630a0024fAE05fDe8b47571D7B39);
        _configureHypChain(blast, 81457, 0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7);
        _configureHypChain(bnb, 56, 0x2971b9Aec44bE4eb673DF1B88cDB57b96eefe8a4);
        _configureHypChain(breeze_contain_secret, 1234200871, 0xF53f7866775f6F0ACB81181D262a7E9559E9584E);
        _configureHypChain(courage_asleep_southern, 123420000, 0x57364C9bB48e391Ce578C720CD8B833445467de0);
        _configureHypChain(cyber, 7560, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(degen, 666666666, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(ethereum, 1, 0xc005dc82818d67AF737725bD4bf75435d065D239);
        _configureHypChain(fantom, 250, 0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7);
        _configureHypChain(gnosis, 100, 0xaD09d78f4c6b9dA2Ae82b1D34107802d380Bb74f);
        _configureHypChain(glue, 1300, 0x3a464f746D23Ab22155710f44dB16dcA53e0775E);
        _configureHypChain(ink, 57073, 0x7f50C5776722630a0024fAE05fDe8b47571D7B39);
        _configureHypChain(lisk, 1135, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(lumia, 1000073017, 0x0dF25A2d59F03F039b56E90EdC5B89679Ace28Bc);
        _configureHypChain(mantle, 5000, 0x398633D19f4371e1DB5a8EFE90468eB70B1176AA);
        _configureHypChain(mode, 34443, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(moonbeam, 1284, 0x094d03E751f49908080EFf000Dd6FD177fd44CC3);
        _configureHypChain(optimism, 10, 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D);
        _configureHypChain(optimism_sepolia, 11155420, 0x6966b0E55883d49BFB24539356a2f8A673E02039);
        _configureHypChain(polygon, 137, 0x5d934f4e2f797775e53561bB72aca21ba36B96BB);
        _configureHypChain(polygon_amoy, 80002, 0x54148470292C24345fb828B003461a9444414517);
        _configureHypChain(rari, 1000012617, 0x65dCf8F6b3f6a0ECEdf3d0bdCB036AEa47A1d615);
        _configureHypChain(sanko, 1996, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(scroll, 534352, 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);
        _configureHypChain(sepolia, 11155111, 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766);
        _configureHypChain(soneium, 1868, 0x3a464f746D23Ab22155710f44dB16dcA53e0775E);
        _configureHypChain(story, 1514, 0x3a464f746D23Ab22155710f44dB16dcA53e0775E);
        _configureHypChain(superposition, 1000055244, 0x5e8a0fCc0D1DF583322943e01F02cB243e5300f6);
        _configureHypChain(unichain, 130, 0x3a464f746D23Ab22155710f44dB16dcA53e0775E);
        _configureHypChain(zero, 543210, 0xd7b351D2dE3495eA259DD10ab4b9300A378Afbf3);
        _configureHypChain(zksync, 324, 0x6bD0A2214797Bc81e0b006F7B74d6221BcD8cb6E);
        _configureHypChain(zora, 7777777, 0xF5da68b2577EF5C0A0D98aA2a58483a68C2f232a);
    }

    function _configureHypChain(
        string memory chain,
        uint32 domainId,
        address mailbox
    ) internal {
        hyperlaneMailboxLookup[chain] = mailbox;
        hyperlaneDomainIdLookup[chain] = domainId;
        vm.label(mailbox, string.concat("hyperlane_mailbox_", chain));
    }

    mapping(string => address) public uniRouterLookup;
    mapping(string => address) public uniQuoterLookup;

    function _loadAllUniRouterInfo() internal {
        address COMMON_SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

        uniRouterLookup[ethereum] = COMMON_SWAP_ROUTER_02;
        uniRouterLookup[arbitrum] = COMMON_SWAP_ROUTER_02;
        uniRouterLookup[optimism] = COMMON_SWAP_ROUTER_02;
        uniRouterLookup[polygon] = COMMON_SWAP_ROUTER_02;
        uniRouterLookup[base] = 0x2626664c2603336E57B271c5C0b26F421741e481;
        uniRouterLookup[avalanche] = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;
        uniRouterLookup[zora] = 0x7De04c96BE5159c3b5CeffC82aa176dc81281557;
        uniRouterLookup[degen] = 0x9c0dF4b950ca19Db6fEC13ab79aD180a9C15a41E;
        uniRouterLookup[bnb] = 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2;
        uniRouterLookup[zksync] = 0x99c56385daBCE3E81d8499d0b8d0257aBC07E8A3;
        uniRouterLookup[blast] = 0x549FEB8c9bd4c12Ad2AB27022dA12492aC452B66;
        uniRouterLookup[zero] = 0xD936711eABD2Ce52747d7122757316C7DFe3599b;
        uniRouterLookup[abstract_chain] = 0x7712FA47387542819d4E35A23f8116C90C18767C;

        uniRouterLookup[sepolia] = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
        uniRouterLookup[arbitrum_sepolia] = 0x101F443B4d1b059569D643917553c771E1b9663E;
        uniRouterLookup[base_sepolia] = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;

        address COMMON_QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;

        uniQuoterLookup[ethereum] = COMMON_QUOTER_V2;
        uniQuoterLookup[arbitrum] = COMMON_QUOTER_V2;
        uniQuoterLookup[optimism] = COMMON_QUOTER_V2;
        uniQuoterLookup[polygon] = COMMON_QUOTER_V2;
        uniQuoterLookup[base] = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
        uniQuoterLookup[avalanche] = 0xbe0F5544EC67e9B3b2D979aaA43f18Fd87E6257F;
        uniQuoterLookup[zora] = 0x11867e1b3348F3ce4FcC170BC5af3d23E07E64Df;
        uniQuoterLookup[degen] = 0xe0b3133592CD29BaA7d958Bc7675C40E83071Ae1;
        uniQuoterLookup[bnb] = 0x78D78E420Da98ad378D7799bE8f4AF69033EB077;
        uniQuoterLookup[zksync] = 0x8Cb537fc92E26d8EBBb760E632c95484b6Ea3e28;
        uniQuoterLookup[blast] = 0x6Cdcd65e03c1CEc3730AeeCd45bc140D57A25C77;
        uniQuoterLookup[abstract_chain] = 0x728BD3eC25D5EDBafebB84F3d67367Cd9EBC7693;

        uniQuoterLookup[sepolia] = 0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;
        uniQuoterLookup[arbitrum_sepolia] = 0x2779a0CC1c3e0E44D2542EC3e79e3864Ae93Ef0B;
        uniQuoterLookup[base_sepolia] = 0xC5290058841028F1614F3A6F0F5816cAd0df5E27;
    }
}
