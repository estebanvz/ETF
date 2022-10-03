// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ETF is Ownable {
    IERC20 public immutable token;
    IERC20 public token_banana;
    IERC20 public token_dai;
    address APE_LP_CONTRACT = 0xd32f3139A214034A0f9777c87eE0a064c1FF6AE2; // MATIC-DAI
    address APE_SWAPER = 0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607;
    address APE_FARMER = 0x54aff400858Dcac39797a81894D9920f16972D1D; // Address contract farmer ape farmer
    address BANANA_TOKEN = 0x5d47bAbA0d66083C52009271faF3F50DCc01023C;
    address DAI_TOKEN = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    uint public totalSupply;
    uint public totalSupplyToken;
    uint public totalSupplyRewards;
    uint public ID_FARM = 2;
    mapping(address => uint) public balanceOf;

    // constructor(address _token) {
    constructor() {
        token = IERC20(APE_LP_CONTRACT);

        token_banana = IERC20(BANANA_TOKEN);
        token.approve(APE_FARMER, 1e59);
        token_banana.approve(APE_SWAPER, 1e59);
        token_dai = IERC20(DAI_TOKEN);
        totalSupplyToken = 0;
        totalSupplyRewards = 0;
    }

    function _mint(address _to, uint _shares) private onlyOwner {
        totalSupply += _shares;
        balanceOf[_to] += _shares;
    }

    function _burn(address _from, uint _shares) private onlyOwner {
        totalSupply -= _shares;
        balanceOf[_from] -= _shares;
    }

    function deposit(uint _amount) external onlyOwner {
        /*
        a = amount
        B = balance of token before deposit
        T = total supply
        s = shares to mint

        (T + s) / T = (a + B) / B 

        s = aT / B
        */
        uint shares;
        if (totalSupply == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply) / totalSupplyToken;
        }

        _mint(msg.sender, shares);
        token.transferFrom(msg.sender, address(this), _amount);
        // APE_FARMER
        totalSupplyToken += _amount;
        MiniApeV2(APE_FARMER).deposit(ID_FARM, _amount, address(this));
    }

    function harvest(uint deadline) external onlyOwner {
        MiniApeV2(APE_FARMER).harvest(ID_FARM, address(this));
        uint256 bananas = token_banana.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = BANANA_TOKEN;
        path[1] = DAI_TOKEN;
        uint256 finalDai = (IApeRouter01(APE_SWAPER).getAmountsOut(
            bananas,
            path
        )[1] * 90) / 100;
        IApeRouter01(APE_SWAPER).swapExactTokensForTokens(
            bananas,
            finalDai,
            path,
            address(this),
            deadline
        );
    }

    function destroy(uint256 quantity) public onlyOwner {
         MiniApeV2(APE_FARMER).harvest(ID_FARM, address(this));
        MiniApeV2(APE_FARMER).withdraw(ID_FARM, quantity, address(this));
        token.transfer(owner(), token.balanceOf(address(this)));
        token_banana.transfer(owner(), token_banana.balanceOf(address(this)));
        token_dai.transfer(owner(), token_dai.balanceOf(address(this)));
    }

    function withdraw(uint _shares) external onlyOwner {
        require(_shares <= balanceOf[msg.sender],"Not enough shares");
        /*
        a = amount
        B = balance of token before withdraw
        T = total supply
        s = shares to burn

        (T - s) / T = (B - a) / B 

        a = sB / T
        */
        uint amount = (_shares * totalSupplyToken) / totalSupply;
        _burn(msg.sender, _shares);
        totalSupplyToken -= amount;
        MiniApeV2(APE_FARMER).withdraw(ID_FARM, amount, address(this));
        token.transfer(msg.sender, amount);
        token_dai.transfer(msg.sender, token_dai.balanceOf(address(this)));

    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
}

interface MiniApeV2 {
    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;
}

interface IApeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        );

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
}
