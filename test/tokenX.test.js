const { assert, expect } = require("chai");
const TokenX = artifacts.require('TokenX');
const { ZERO_ADDRESS } = require('@openzeppelin/test-helpers/src/constants');
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const fromWei = (_amount, _unit) => web3.utils.fromWei(_amount.toString(), _unit);
const toWei = (_amount, _unit) => web3.utils.toWei(_amount.toString(), _unit);


contract('TokenX', async ([deployer, user1, user2]) => {
    beforeEach(async () => {
        this.contract = await TokenX.new("My Token", "MYT", deployer, { from: deployer });
    })

    describe('deployment', () => {
        it('should deploy contract properly', async () => {
            expect(this.contract.address).not.equal('');
            expect(this.contract.address).not.equal(ZERO_ADDRESS);
        })
    })

    describe('getAdmin', () => {
        it('should return admin address', async () => {
            const getAdmin = await this.contract.getAdmin();
            expect(getAdmin).to.equal(deployer);
        })
    })

    describe('isTrustedForwarder', () => {
        it('should validate if account is TrustedForwarder address', async () => {
            const isTrustedForwarder = await this.contract.isTrustedForwarder(deployer);
            expect(isTrustedForwarder).to.equal(true);
        })

        it('should validate if account is TrustedForwarder address', async () => {
            const isTrustedForwarder = await this.contract.isTrustedForwarder(user1);
            expect(isTrustedForwarder).to.equal(false);
        })
    })
    
    describe('trustedForwarder', () => {
        it('should return trusted forwader address', async () => {
            const trustedForwarder = await this.contract.trustedForwarder();
            expect(trustedForwarder).to.equal(deployer);
        })
    })

    describe('getEthBalance', () => {
        it('should return contract ETHER balance', async () => {
            const _amount = toWei(2, 'ether');

            await web3.eth.sendTransaction({
                from: deployer,
                to: this.contract.address,
                value: _amount
            });
            const getEthBalance = await this.contract.getEthBalance();
            expect(getEthBalance.toString()).to.equal(_amount)
        }) 
    })

    describe('depositETH', () => {
        it('should depositETH to contract', async () => {
            const _amount = toWei(2, 'ether');

            await this.contract.depositETH({ from: deployer, value: _amount });
            const getEthBalance = await this.contract.getEthBalance();
            expect(getEthBalance.toString()).to.equal(_amount)
        }) 
    })


    describe('balanceOf', () => {
        it('should return account balance', async () => {
            const balanceOfDeployer = await this.contract.balanceOf(deployer);
            const totalSupply = await this.contract.totalSupply();
            console.log(fromWei(balanceOfDeployer, 'ether'))
            expect(balanceOfDeployer.toString()).to.equal(totalSupply.toString());
        })
    })
 
    // describe('transfer', () => {
    //     let _amount;
    //     let _reciept;

    //     beforeEach(async () => {
    //         _amount = toWei(100, 'ether');
    //         _reciept = await this.contract.transfer(user1, _amount, { from: deployer });
    //     })

    //     it('should transfer token properly', async () => {
    //         const balanceOfDeployer = await this.contract.balanceOf(deployer);
    //         const balanceOfUser1 = await this.contract.balanceOf(user1);

    //         expect(balanceOfDeployer.toString()).to.equal(toWei(9900, 'ether'));
    //         expect(balanceOfUser1.toString()).to.equal(_amount);
    //     })

    //     it('should fails if insufficient balance', async () => {
    //         try {
                
    //         } catch (error) {
                
    //         }
    //     })
    // })
    
    
})