pragma solidity ^0.8.0;


interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}


interface IERC3156FlashBorrower {

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}


interface IERC3156FlashLender {

    function maxFlashLoan(address token) external view returns (uint256);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

interface IGeneralizedCaller {
    function makeCalls(address[] calldata _targets, bytes[] calldata _datas, uint256 payAmount)
    external
    payable;
}


contract GeneralizedDaiFlashLoan is IERC3156FlashBorrower {

    struct ParamsPay {
        address generalizedCaller;
        address[] targets;
        bytes[] calldatas;
        uint256 payAmount;
    }
    mapping (address => bool) private whitelist;

    address daiLender = 0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853; // hardcoded init to DssFlashLoan, can be changed
    //address daiLenderGoerli = 0x0a6861D6200B519a8B9CFA1E7Edd582DD1573581;
    address lender;

    constructor () public {
        whitelist[msg.sender] = true;
        whitelist[daiLender] = true;
        lender = daiLender;
    }

    fallback () external payable {}

    function isWhitelisted(address user) public view returns (bool) {
        return whitelist[user];
        return whitelist[daiLender];
    }

    function addToWhitelist(address newUser) public {
        require(isWhitelisted(msg.sender), "unauthorized");
        whitelist[newUser] = true;
    }

    function setLender(address newLender) public {
        require(isWhitelisted(msg.sender), "unauthorized");
        lender = newLender;
    }

    function withdrawEth(address payable to) public {
        require(isWhitelisted(msg.sender), "unauthorized");
        to.send(address(this).balance);
    }

    function erc20Transfer(address token, address to, uint amount) public {
        require(isWhitelisted(msg.sender), "unauthorized");
        IERC20(token).transfer(to, amount);
    }

    function erc20Approve(address token, address to, uint amount) public {
        require(isWhitelisted(msg.sender), "unauthorized");
        IERC20(token).approve(to, amount);
    }
    
    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );

        (ParamsPay memory params) = abi.decode(data, (ParamsPay));

        IGeneralizedCaller(params.generalizedCaller).makeCalls(params.targets, params.calldatas, params.payAmount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount,
        ParamsPay calldata params
    ) public {
        require(isWhitelisted(msg.sender), "unauthorized");

        uint256 _allowance = IERC20(token).allowance(address(this), address(lender));
        uint256 _fee = IERC3156FlashLender(lender).flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20(token).approve(lender, _allowance + _repayment);

        IERC3156FlashLender(lender).flashLoan(this, token, amount, abi.encode(params));
    }

    function makeCall(address _target, bytes memory _data) internal {
        require(_target != address(0), "target-invalid");
        assembly {
            let succeeded := call(gas(), _target, 0, add(_data, 0x20), mload(_data), 0, 0)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    let size := returndatasize()
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
        }
    }

    function makeCalls(
        address[] calldata _targets,
        bytes[] calldata _datas,
        uint256 payAmount
    )
    external
    payable
    {
        require(isWhitelisted(msg.sender), "permission-denied");

        for (uint i = 0; i < _targets.length; i++) {
            makeCall(_targets[i], _datas[i]);
        }

        if (payAmount > 0){
            block.coinbase.send(payAmount);
        }
    }


}