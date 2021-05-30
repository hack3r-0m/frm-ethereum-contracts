var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = process.env.NMONIC;
var rinkebyClientUrl = process.env.RINKEBY_CLIENT_URL

module.exports = {

  plugins: [
    "truffle-security",
    "truffle-plugin-verify"
],

  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, rinkebyClientUrl);},
      network_id: 4,
      gas: 4612388 // Gas limit used for deploys
    },
  },
  compilers: {
    solc: {
      version: "0.8.4"
    }
  }
};
