// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TicTacToeBet {
 address payable public playerX;
 address payable public playerO;
 uint256 public betAmount;
 bool public gameStarted;
 bool public gameEnded;

 enum GameResult { None, XWins, OWins, Draw }
 GameResult public result;

 mapping(address => bool) public hasDeposited;
 mapping(address => bool) public hasWithdrawn;

 // Events for better tracking
 event PlayerDeposited(address player, uint256 amount);
 event GameStarted();
 event ResultSet(GameResult result, address setter);
 event Withdrawal(address player, uint256 amount);

 modifier onlyPlayers() {
 require(msg.sender == playerX || msg.sender == playerO, "Not a player");
 _;
 }

 modifier gameNotEnded() {
 require(!gameEnded, "Game has ended");
 _;
 }

 constructor(address payable _playerX, address payable _playerO, uint256 _betAmount) {
 require(_playerX != address(0) && _playerO != address(0), "Invalid player addresses");
 require(_playerX != _playerO, "Players must be different");
 require(_betAmount > 0, "Bet amount must be greater than 0");
 
 playerX = _playerX;
 playerO = _playerO;
 betAmount = _betAmount;
 gameStarted = false;
 gameEnded = false;
 result = GameResult.None;
 }

 function deposit() external payable onlyPlayers gameNotEnded {
 require(msg.value == betAmount, "Incorrect bet amount");
 require(!hasDeposited[msg.sender], "Already deposited");

 hasDeposited[msg.sender] = true;
 emit PlayerDeposited(msg.sender, msg.value);

 // Check if both players have deposited
 if (hasDeposited[playerX] && hasDeposited[playerO]) {
 gameStarted = true;
 emit GameStarted();
 }
 }

 function setResult(uint8 _result) external onlyPlayers gameNotEnded {
 require(gameStarted, "Game not started");
 require(result == GameResult.None, "Result already set");
 require(_result <= uint8(GameResult.Draw), "Invalid result");

 result = GameResult(_result);
 gameEnded = true;
 emit ResultSet(result, msg.sender);
 }

 function withdraw() external onlyPlayers {
 require(gameEnded, "Game not ended");
 require(result != GameResult.None, "Result not set");
 require(!hasWithdrawn[msg.sender], "Already withdrawn");
 require(hasDeposited[msg.sender], "Did not deposit");

 uint256 payoutAmount = 0;
 
 if (result == GameResult.Draw) {
 // In case of draw, each player gets their bet back
 payoutAmount = betAmount;
 } else if ((result == GameResult.XWins && msg.sender == playerX) ||
 (result == GameResult.OWins && msg.sender == playerO)) {
 // Winner gets both bets (total pot)
 payoutAmount = betAmount * 2;
 } else {
 revert("You lost, no payout");
 }

 require(address(this).balance >= payoutAmount, "Insufficient contract balance");
 
 hasWithdrawn[msg.sender] = true;

 // Use call instead of transfer for better gas handling
 (bool success, ) = payable(msg.sender).call{value: payoutAmount}("");
 require(success, "Transfer failed");
 
 emit Withdrawal(msg.sender, payoutAmount);
 }

 // Emergency function to withdraw remaining balance if both players have withdrawn
 function withdrawRemaining() external onlyPlayers {
 require(gameEnded, "Game not ended");
 require(hasWithdrawn[playerX] && hasWithdrawn[playerO], "Not all players have withdrawn");
 require(address(this).balance > 0, "No remaining balance");

 uint256 remaining = address(this).balance;
 uint256 halfRemaining = remaining / 2;

 if (msg.sender == playerX) {
 (bool success, ) = playerX.call{value: halfRemaining}("");
 require(success, "Transfer to playerX failed");
 } else {
 (bool success, ) = playerO.call{value: halfRemaining}("");
 require(success, "Transfer to playerO failed");
 }
 }

 // Function to check contract balance
 function getContractBalance() external view returns (uint256) {
 return address(this).balance;
 }

 // Function to check if both players have deposited
 function bothPlayersDeposited() external view returns (bool) {
 return hasDeposited[playerX] && hasDeposited[playerO];
 }

 // Function to get game status
 function getGameStatus() external view returns (
 bool _gameStarted,
 bool _gameEnded,
 GameResult _result,
 uint256 _contractBalance,
 bool _playerXDeposited,
 bool _playerODeposited
 ) {
 return (
 gameStarted,
 gameEnded,
 result,
 address(this).balance,
 hasDeposited[playerX],
 hasDeposited[playerO]
 );
 }

 // Fallback function to reject direct ETH transfers
 receive() external payable {
 revert("Direct transfers not allowed, use deposit()");
 }

 fallback() external payable {
 revert("Function not found");
 }
}
