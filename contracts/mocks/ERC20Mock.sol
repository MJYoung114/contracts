// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ERC20Mock is ERC20PresetMinterPauser {
  constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {}

  event TransferCalled(address sender, address recipient, uint256 amount);

  bool shouldMockTransfer = true;

  function setShouldMockTransfer(bool _value) public {
    shouldMockTransfer = _value;
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    emit TransferCalled(_msgSender(), recipient, amount);
    if (shouldMockTransfer) {
      return true;
    } else {
      return super.transfer(recipient, amount);
    }
  }
}

contract ERC20MockWithPublicMint is ERC20Mock {
  constructor(string memory name, string memory symbol) ERC20Mock(name, symbol) {}

  // Minting is public for easy testing on the mock.
  function mint(uint256 amount) public {
    super._mint(msg.sender, amount);
  }

  // Minting is public for easy testing on the mock.
  function mintFor(uint256 amount, address user) public {
    super._mint(user, amount);
  }
}
