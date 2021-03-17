// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
import "./IERC20.sol";
import "./IRecipient.sol";
import "./SafeMath.sol";


interface UniswapReserves{
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface WETHwithdraw{
    function withdraw(uint wad) external;
}

contract TokenX is IRelayRecipient,IERC20{
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;


    address public trustedForwarder;
    string public _version;

    address private admin;
    address private _uniswapAddress;
    uint256 private _ethTransferOverhead;
    address private WETH;
    bool private _sortedOrder;
    bool private _sortedOrderLock;

    constructor(address _forwarder) {
        trustedForwarder=address(_forwarder);
        _name = "TokenX";
        _symbol = "Tx";
        _decimals = 18;
        WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        admin = msg.sender;
        _mint(msg.sender,1e19);
    }

    receive() external payable {  }

    function getAdmin() public view returns(address) {
        return admin;
    }

    function isTrustedForwarder(address forwarder) public override view returns(bool) {
        return forwarder == trustedForwarder;
    }


    function _msgSender() internal virtual override view returns (address payable ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }

    function _msgData() internal virtual  override view returns (bytes memory ret) {
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

    function name() public view returns (string memory) {
        return _name;
    }


    function symbol() public view returns (string memory) {
        return _symbol;
    }


    function decimals() public view returns (uint8) {
        return _decimals;
    }


    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }


    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }


    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }


    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }


    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }


    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

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
            _tokensIn = ethIn.mul(reserve0).div(reserve1);
        }
        else {
            _tokensIn = ethIn.mul(reserve1).div(reserve0);
        }
    }

    function _verifyTokensIn(address payer, uint256 gasClaim) internal view returns(bool) {
        uint256 _ethToRefund = tx.gasprice.mul(gasClaim);
        return balanceOf(payer) >= _getTokensIn(_ethToRefund);
    }


    function _refundFee(address claimer, address payer, uint256 gasClaim) internal virtual {
        uint256 _ethToRefund = tx.gasprice.mul(gasClaim);
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
