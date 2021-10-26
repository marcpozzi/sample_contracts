# Sample Contracts

### Generalized Dai flash loan contract

[GeneralizedDaiFlashLoan.sol](contracts/GeneralizedDaiFlashLoan.sol) is a contract that allows taking a Dai flash loan (up to 500 million Dai) and make an arbitrary number of calls to any external contracts during flash loan execution as long as correct target contract addresses and corresponding calldatas are provided as arguments. Theres also a 'payAmount' parameter which is used to transfer ETH to block.coinbase in order to use this contract with Flashbots.


# 