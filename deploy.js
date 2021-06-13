const ethers = require('ethers')

const CLT = require('./build/contracts/CreativeLabsToken.json')
const CLTX = require('./build/contracts/CreativeLabsXToken.json')
const Cestaking = require('./build/contracts/Cestaking.json')
const CestakingFarm = require('./build/contracts/CestakingFarm.json')

const provider = new ethers.providers.JsonRpcProvider(
  process.env.RINKEBY_CLIENT_URL,
)

let wallet = new ethers.Wallet.fromMnemonic(process.env.NMONIC)
wallet = wallet.connect(provider)

async function exec() {
  const CLTFactroy = new ethers.ContractFactory(
    // eslint-disable-line
    CLT.abi,
    CLT.bytecode,
    wallet,
  )
  const deploy_CLT = await CLTFactroy.deploy()
  console.log(deploy_CLT)

  const CLTXFactroy = new ethers.ContractFactory(
    CLTX.abi,
    CLTX.bytecode,
    wallet,
  )
  const deploy_CLTX = await CLTXFactroy.deploy()
  console.log(deploy_CLTX)

  const CestakingFactroy = new ethers.ContractFactory(
    Cestaking.abi,
    Cestaking.bytecode,
    wallet,
  )

  const timestamp = Date.now()

  const deploy_Cestaking = await CestakingFactroy.deploy()
  console.log(deploy_Cestaking)

  const CestakingFarmFactroy = new ethers.ContractFactory(
    CestakingFarm.abi,
    CestakingFarm.bytecode,
    wallet,
  )

  const deploy_CestakingFarm = await CestakingFarmFactroy.deploy(
    'CE STAKING FARM',
    deploy_CLT.address,
    deploy_CLTX.address,
    timestamp,
    timestamp + 86400000,
    timestamp + 86400000 + 86400000,
    timestamp + 86400000 + 86400000 + 86400000,
    '3300000000000000000000',
  )
  console.log(deploy_CestakingFarm)
}

exec()
