import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'RWAIOFT'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    // deployer = .env 의 PRIVATE_KEY (MNEMONIC 이 있으면 MNEMONIC 우선) 지갑.
    // 이 지갑이 owner / delegate 가 되고 10억 RWAI 를 전량 받는다.
    console.log(`Network : ${hre.network.name}`)
    console.log(`Deployer: ${deployer}  (owner / delegate / 1,000,000,000 RWAI 수령)`)

    // EndpointV2 는 @layerzerolabs/toolbox-hardhat 가 네트워크 eid 기준으로 자동 주입
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    if (hre.network.config.oftAdapter != null) {
        console.warn(`oftAdapter configuration found on OFT deployment, skipping OFT deployment`)
        return
    }

    console.log(`EndpointV2: ${endpointV2Deployment.address}`)
    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero EndpointV2
            deployer, // owner & delegate (10억 RWAI 전량 수령)
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })
    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
}

deploy.tags = [contractName]

export default deploy
