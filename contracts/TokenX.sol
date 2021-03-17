// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "./IRecipient.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface UniswapReserves{
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface WETHwithdraw{
    function withdraw(uint wad) external;
}

contract TokenX is IRelayRecipient, ERC20 { 
    address public trustedForwarder;
    string public _version;

    address private admin;
    address private _uniswapAddress;
    uint256 private _ethTransferOverhead;
    address private WETH;
    bool private _sortedOrder;
    bool private _sortedOrderLock;

    constructor(string memory _name, string memory _symbol, address _forwarder) ERC20(_name, _symbol) {
        trustedForwarder=address(_forwarder);
        WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        admin = msg.sender;
        _mint(msg.sender,10000 ether);
    }

    receive() external payable {  }

    function getAdmin() public view returns(address) {
        return admin;
    }

    function isTrustedForwarder(address forwarder) public override view returns(bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender() internal virtual override view returns (address payable) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            address payable ret;
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
            return ret;
        } else {
            return payable(msg.sender);
        }
    }

    function _msgData() internal virtual override view returns (bytes memory ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            assembly {
                let ptr := mload(0x40)
                let size := sub(calldatasize(),20)
                mstore(ptr, 0x20)
                mstore(add(ptr,32), size)
                calldatacopy(add(ptr,64), 0, size)
                return(ptr, add(size,64))
            }
        } else {
            return msg.data;
        }
    }


    function versionRecipient() external virtual  override view returns (string memory){
        return _version;
    }


     function setOverhead(uint256 overhead) public virtual {
        require((msg.sender == admin && _ethTransferOverhead == 0), "Permission Denied");
        _ethTransferOverhead = overhead;
    }

    function setUniswap(address uniswapPair) public virtual {
        require((msg.sender == admin && _uniswapAddress == address(0)), "Permission Denied");
        _uniswapAddress = uniswapPair;
    }

    function setUniswap(bool order) public virtual {
        require((msg.sender == admin && _sortedOrderLock != true),"Permission Denied");
        _sortedOrderLock = true;
        _sortedOrder = order;
    }

    function withdrawTokens(uint256 amount) public virtual {
        require((msg.sender == admin),"Permission Denied");
        _transfer(address(this), admin, amount);
    }

    function withdrawETH(uint256 amount) public payable virtual {
        require((msg.sender == admin),"Permission Denied");
        payable(admin).transfer(amount);
    }

    function depositETH() public payable virtual { }

    function getUniswapAddress() public view returns(address) {
        return _uniswapAddress;
    }

    function getOverhead() public view returns(uint256) {
        return _ethTransferOverhead;
    }

    function getSortedOrder() public view returns(bool) {
        return _sortedOrder;
    }

    function getTokenBalance() public view returns(uint256) {
        return balanceOf(address(this));
    }

    function getEthBalance() public view returns(uint256) {
        return address(this).balance;
    }



    function _getTokensIn(uint256 ethIn) public view returns(uint256 _tokensIn) {
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = UniswapReserves(_uniswapAddress).getReserves();
        blockTimestampLast;
        if (_sortedOrder) {
            _tokensIn = (ethIn * reserve0) / reserve1;
        }
        else {
            _tokensIn = (ethIn * reserve1) / reserve0;
        }
    }

    function _verifyTokensIn(address payer, uint256 gasClaim) internal view returns(bool) {
        uint256 _ethToRefund = tx.gasprice * gasClaim;
        return balanceOf(payer) >= _getTokensIn(_ethToRefund);
    }


    function _refundFee(address claimer, address payer, uint256 gasClaim) internal virtual {
        uint256 _ethToRefund = tx.gasprice * gasClaim;
        _transfer(payer, address(this), _getTokensIn(_ethToRefund));
        payable(claimer).transfer(_ethToRefund);
    }


    function trustedForwarderRefundFee(address payer, uint256 gasClaim) external payable virtual {
        require(msg.sender == trustedForwarder, "Illegal Sender.");
        _refundFee(tx.origin, payer, gasClaim);
    }


    function transfer_eth(address recipient) public payable virtual {
        transfer_eth(recipient, true);
    }

    function transfer_eth(address recipient, bool refundForward) public payable virtual {
        require(_verifyTokensIn(_msgSender(), _ethTransferOverhead));
        payable(recipient).transfer(msg.value);
        if (refundForward) {
            _refundFee(recipient, _msgSender(), _ethTransferOverhead);
        }
        else {
            _refundFee(_msgSender(), _msgSender(), _ethTransferOverhead);
        }

    }

    function transferWETH(address recipient, uint256 amount) public payable virtual {
        IERC20(WETH).transferFrom(_msgSender(), address(this), amount);
        WETHwithdraw(WETH).withdraw(amount);
        payable(recipient).transfer(amount);
    }


    function transfer_tokens(address receiver, uint256 amount, address token) public virtual{
        IERC20(address(token)).transferFrom(_msgSender() ,address(receiver), amount);
    }
}
