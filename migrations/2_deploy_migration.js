const TokenX = artifacts.require('TokenX');

module.exports = async (deployer, network, accounts) => {
    await deployer.deploy(TokenX, accounts[0]);
}