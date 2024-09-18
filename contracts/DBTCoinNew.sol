// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/ISwapRouter.sol";
import "./interface/ISwapFactory.sol";
import "./interface/ISwapPair.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DBTCoinNew is ERC20, Ownable, ReentrancyGuard {
    mapping(address => bool) public _feeWhiteList;


    ISwapRouter public _swapRouter;

    using Address for address payable;
    address public currency;


    mapping(address => bool) public _swapPairList;


    uint256 private constant MAX = ~uint256(0);


    TokenDistributor public _tokenDistributor;



    uint256 public _buyFundFee;

    uint256 public _buyLPFee;

    uint256 public buy_burnFee;


    uint256 public _buyMarketingFee;


    uint256 public _sellFundFee;

    uint256 public _sellLPFee;

    uint256 public sell_burnFee;

    uint256 public _sellMarketingFee;

    uint256 public _sellReflowFee;


    uint256 public _reflowAmount;


    bool public currencyIsEth;


    uint256 public startTradeBlock;



    address public _mainPair;

    uint256 public lastLpBurnTime;

    uint256 public lpBurnRate;

    uint256 public lpBurnFrequency;


    uint256 public _tradeFee;

    bool public enableOffTrade;



    uint256 public totalFundAmountReceive;




    address public burnLiquidityAddress;

    uint256 public dailyDropPercentage;

    uint256 public openingPrice;
    uint256 public lastUpdateTimestamp;

    uint256 public allToFunder;


    address public LPDividendsAddress;
    address public MarketingAddress;
    address payable public fundAddress;

    address public MintBDCReceiveAddress;
    address public addLPLock30ReceiveAddress;
    address public addLPLock60ReceiveAddress;
    address public addLPLock90ReceiveAddress;
    address public addLPLock365ReceiveAddress;

    constructor() ERC20('DBTCoin', 'DBTC') Ownable(msg.sender) {

        currency = 0x55d398326f99059fF775485246999027B3197955;
        _swapRouter = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        burnLiquidityAddress = 0x374D9d8757A3771b53C2586f10464919b0ABBfE3;
        fundAddress = payable(0x2f7689Ff67A1a77A39b912E923D6d4e7E40725Ae);
        LPDividendsAddress = 0x4B99EFb473A9e8E963EcF6b1863E29B6c85BeBd7;
        MarketingAddress = 0x2dF69D052c76dc5DB26E6e87F32b66D318452e79;
        MintBDCReceiveAddress = 0x4cd073CAc99a6087EAD8c149A22eE879f521CAfe;
        addLPLock30ReceiveAddress = 0x04f0A1fdABd9f2DB3C25E1a857cB84Af45d4bA91;
        addLPLock60ReceiveAddress = 0xC5cb3ce8161Ed6b3652a4916fE9BD6D2BE21bb3d;
        addLPLock90ReceiveAddress = 0x8b547279468791F575189bc865FC8387f73A97B2;
        addLPLock365ReceiveAddress = 0xF4a990E15406412f3e4494669D8b37d81DeeC952;


        MintBDCReceiveAddress = 0x63FE2ec3546add2b2954d1812bF5dE2a74365301;

        uint256 _mintAmount = 67200 * 10 ** decimals();
        _mint(MintBDCReceiveAddress, _mintAmount);

        uint256 _addLPLockAmount = 4200 * 10 ** decimals();

        _mint(addLPLock30ReceiveAddress, _addLPLockAmount);
        _mint(addLPLock60ReceiveAddress, _addLPLockAmount);
        _mint(addLPLock90ReceiveAddress, _addLPLockAmount);
        _mint(addLPLock365ReceiveAddress, _addLPLockAmount);


        _buyFundFee = 100;
        _buyLPFee = 100;
        _buyMarketingFee = 100;

        _sellFundFee = 200;
        _sellLPFee = 200;
        sell_burnFee = 200;
        _sellMarketingFee = 200;
        _sellReflowFee = 200;

        _tradeFee = 500;

        lpBurnRate = 20;
        lpBurnFrequency = 1 hours;

        ISwapFactory swapFactory = ISwapFactory(_swapRouter.factory());
        _mainPair = swapFactory.createPair(address(this), currency);

        _swapPairList[_mainPair] = true;

        _feeWhiteList[fundAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0xdead)] = true;
        _feeWhiteList[LPDividendsAddress] = true;
        _feeWhiteList[MarketingAddress] = true;
        _feeWhiteList[MintBDCReceiveAddress] = true;
        _feeWhiteList[addLPLock30ReceiveAddress] = true;
        _feeWhiteList[addLPLock60ReceiveAddress] = true;
        _feeWhiteList[addLPLock90ReceiveAddress] = true;
        _feeWhiteList[addLPLock365ReceiveAddress] = true;

        enableOffTrade = true;

        currencyIsEth = false;

        _tokenDistributor = new TokenDistributor(currency);

    }




    function transfer(address recipient, uint256 amount) public override returns (bool) {

        _transferT(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address from, address recipient, uint256 value) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transferT(from, recipient, value);
        return true;

    }

    function _transferT(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balanceOf(from) >= amount, "balanceNotEnough");

        bool takeFee;
        bool isSell;


        if (startTradeBlock == 0 && enableOffTrade) {
            if (
                !_feeWhiteList[from] &&
            !_feeWhiteList[to] &&
            !_swapPairList[from] &&
            !_swapPairList[to]
            ) {
                require(!isContract(to), "cant add other lp");
            }
        }

        if (_swapPairList[from] || _swapPairList[to]) {
            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {

                if (enableOffTrade) {
                    require(startTradeBlock > 0);
                }
                takeFee = true; // just swap fee
            }
            if (_swapPairList[to]) {
                isSell = true;
            }
        }

        if (_feeWhiteList[from] || _feeWhiteList[to]) {
            _basicTransfer(from, to, amount);
        } else {

            _tokenTransfer(
                from,
                to,
                amount,
                takeFee,
                isSell
            );
        }


    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private {

        uint256 sellBurnFee = isSell ? sell_burnFee : buy_burnFee;
        uint256 buyFee;
        uint256 sellFee;
        uint256 burnFee;
        uint256 amount;
        uint256 transferAmount;
        uint256 sellReflowFee;

        updateOpeningPrice(getPrice());

        if (takeFee) {
            if (isSell) {

                uint256 _toSellLPFee = tAmount * _sellLPFee / 10000;
                _basicTransfer(sender,LPDividendsAddress,_toSellLPFee);
                (sellFee, burnFee, sellReflowFee, amount) = allSellFeeToAmount(tAmount, sellBurnFee);
                _reflowAmount += sellReflowFee;
                amount = amount - _toSellLPFee;
                allToFunder += sellFee;
            } else {
                uint _toBuyLPFee = tAmount * _buyLPFee / 10000;
                _basicTransfer(sender,LPDividendsAddress,_toBuyLPFee);
                (buyFee, amount) = allBuyFeeToAmount(tAmount);
                amount = amount - _toBuyLPFee;
                allToFunder += buyFee;
            }
        } else if (!_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
            transferAmount = tAmount * _tradeFee / 10000;
            amount = tAmount - transferAmount;
        }


        if (takeFee) {
            if (isSell) {
                _basicTransfer(sender, address(this), sellFee);
                _basicTransfer(sender, address(0xdead), burnFee);
            } else {
                _basicTransfer(sender, address(this), buyFee);
            }

        } else {
            if (block.timestamp >= lastLpBurnTime + lpBurnFrequency && sender == burnLiquidityAddress) {
                autoBurnLiquidityPairTokens();
            }
            if (_reflowAmount > 0) {
                swapSellReflow(_reflowAmount);
            }
            if (transferAmount > 0) {
                _basicTransfer(sender, fundAddress, transferAmount);
                totalFundAmountReceive += transferAmount;
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance > 0 && contractTokenBalance <= allToFunder) {
                swapForFund(contractTokenBalance);

            }
        }

        if (amount > 0) {
            _basicTransfer(sender, recipient, amount);
        } else {
            revert("Transfer amount after fees is zero");
        }


    }

    function swapForFund(uint256 amount) private nonReentrant {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;
        _approve(address(this), address(_swapRouter), amount);

        uint256 before = IERC20(currency).balanceOf(address(this));



        try
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            _calculateSwapToCurrencyAmount(amount),
            path,
            address(_tokenDistributor),
            block.timestamp
        )
        {
            uint256 _after = IERC20(currency).balanceOf(address(_tokenDistributor));
            uint256 currencyAmount = _after - before;
            uint256 _toAmount = currencyAmount / 2;
            SafeERC20.safeTransferFrom(IERC20(currency),address(_tokenDistributor), address(this), currencyAmount);
            SafeERC20.safeTransfer(IERC20(currency),  address(fundAddress), _toAmount);
            SafeERC20.safeTransfer(IERC20(currency),  address(MarketingAddress), currencyAmount - _toAmount);
            totalFundAmountReceive += amount;
            allToFunder = 0;
        } catch {

            emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(amount);
        }

    }

    function _calculateSwapToCurrencyAmount(uint256 amount) public view returns (uint256) {
        uint256 price = getPrice();
        uint256 Slippage = 2;
        price = amount * price / 10 ** decimals();
        return price - price * Slippage / 100;
    }

    function swapSellReflow(uint256 amount) private nonReentrant {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;
        uint256 half = amount / 2;
        IERC20 _c = IERC20(currency);
        _approve(address(this), address(_swapRouter), amount);
        try
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            half,
            _calculateSwapToCurrencyAmount(half),
            path,
            address(_tokenDistributor),
            block.timestamp
        )
        {
            _reflowAmount = _reflowAmount - half;
        } catch {

            emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(half);
        }

        uint256 newBal = _c.balanceOf(address(_tokenDistributor));
        if (newBal != 0) {
            _c.transferFrom(address(_tokenDistributor), address(this), newBal);

        }

        if (newBal > 0) {
            IERC20(currency).approve(address(_swapRouter), newBal);

            try
            _swapRouter.addLiquidity(
                address(this),
                address(currency),
                half,
                newBal,
                0,
                0,
                address(0xdead),
                block.timestamp
            )
            {
                _reflowAmount = 0;
            } catch {
                emit Failed_addLiquidity();
            }
        }
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _transfer(sender, recipient, amount);
        return true;
    }


    function Claims(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(msg.sender).sendValue(amount);
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    modifier onlyFunder() {
        require(owner() == msg.sender || burnLiquidityAddress == msg.sender, "!burnLiquidityAddress");
        _;
    }

    event AutoNukeLP();

    function burnLiquidityPairTokens() external onlyFunder {
        require(block.timestamp >= lastLpBurnTime + lpBurnFrequency, "Not yet");
        autoBurnLiquidityPairTokens();
    }

    function autoBurnLiquidityPairTokens() internal {

        lastLpBurnTime = block.timestamp;

        uint256 liquidityPairBalance = super.balanceOf(_mainPair);
        if (liquidityPairBalance < 100 * 10 ** decimals()) {
            return;
        }

        uint256 amountToBurn = liquidityPairBalance * lpBurnRate / 10000;

        if (amountToBurn > 0) {
            _basicTransfer(_mainPair, address(0xdead), amountToBurn);

            ISwapPair pair = ISwapPair(_mainPair);
            pair.sync();
            emit AutoNukeLP();
            return;
        }
    }

    function allSellFee() public view returns (uint256) {
        return _sellFundFee  + _sellMarketingFee + _sellReflowFee;
    }

    function allSellFeeToAmount(uint256 amount, uint256 sellBurnFee) public view returns (uint256, uint256, uint256, uint256) {
        uint256 fee = amount * allSellFee() / 10000;
        uint256 burn = amount * sellBurnFee / 10000;
        burn = burn + calculateFee(amount);
        uint256 sellReflowFee = amount * _sellReflowFee / 10000;
        return (fee, burn, sellReflowFee, amount - fee - burn);
    }


    function updateOpeningPrice(uint256 currentPrice) internal {

        if (block.timestamp >= lastUpdateTimestamp + 24 hours) {
            openingPrice = currentPrice;
            lastUpdateTimestamp = block.timestamp;
        }
        if (currentPrice < openingPrice && openingPrice > 0) {
            dailyDropPercentage = (openingPrice - currentPrice) * 10000 / openingPrice;
        } else {
            dailyDropPercentage = 0;
        }

    }

    function calculateFee(uint256 amount) public view returns (uint256 burnAmount) {
        if (dailyDropPercentage <= 500) {
            return (0);
        } else if (dailyDropPercentage <= 1000) {
            return (amount * 500 / 10000);
        } else if (dailyDropPercentage <= 1500) {
            return (amount * 1000 / 10000);
        } else if (dailyDropPercentage <= 2000) {
            return (amount * 1500 / 10000);
        } else if (dailyDropPercentage <= 3000) {
            return (amount * 2000 / 10000);
        } else if (dailyDropPercentage <= 4000) {
            return (amount * 2500 / 10000);
        } else {
            return (amount * 2500 / 10000);
        }
    }

    function getPrice() public view returns (uint256 price) {
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint256 reserve0, uint256 reserve1,) = mainPair.getReserves();

        if (mainPair.token0() == address(this)) {

            return reserve1 * 10 ** decimals() / reserve0;
        } else {

            return reserve0 * 10 ** decimals() / reserve1;
        }
    }


    function allBuyFee() public view returns (uint256) {
        return _buyFundFee  + _buyMarketingFee;
    }

    function allBuyFeeToAmount(uint256 amount) public view returns (uint256, uint256) {
        uint256 fee = amount * allBuyFee() / 10000;
        return (fee, amount - fee);
    }

    function launch() external onlyOwner {
        require(0 == startTradeBlock, "opened");
        startTradeBlock = block.number;
        lastLpBurnTime = block.timestamp;
    }

    function balanceOf(address account) public view override returns (uint256) {

        return super.balanceOf(account);
    }


    event Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 value
    );
    event Failed_swapSellReflow(
        uint256 value
    );
    event Failed_addLiquidity();

    receive() external payable {

    }

    function setFeeWhiteList(address account, bool status) external onlyOwner {
        require(account != address(0), "Invalid address: cannot be zero address");
        _feeWhiteList[account] = status;
    }

    function getFeeWhiteList(address account) external view returns (bool) {
        require(account != address(0), "Invalid address: cannot be zero address");
        return _feeWhiteList[account];
    }


    function getSwapRouter() external view returns (ISwapRouter) {
        return _swapRouter;
    }


    function getCurrency() external view returns (address) {
        return currency;
    }

    function setSwapPairList(address pair, bool status) external onlyOwner {
        require(pair != address(0), "Invalid address: cannot be zero address");
        _swapPairList[pair] = status;
    }

    function getSwapPairList(address pair) external view returns (bool) {
        return _swapPairList[pair];
    }


    function getTokenDistributor() external view returns (TokenDistributor) {
        return _tokenDistributor;
    }

    function setBuyFees(
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee
    ) external onlyOwner {
        uint256 MAX_TOTAL_FEE = 5000;

        uint256 totalFee = fundFee + lpFee + burnFee + marketingFee;
        require(totalFee <= MAX_TOTAL_FEE, "Total buy fees exceed maximum limit");

        _buyFundFee = fundFee;
        _buyLPFee = lpFee;
        buy_burnFee = burnFee;
        _buyMarketingFee = marketingFee;
    }

    function getBuyFees() external view returns (
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee
    ) {
        return (_buyFundFee, _buyLPFee, buy_burnFee, _buyMarketingFee);
    }

    function setSellFees(
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee,
        uint256 reflowFee
    ) external onlyOwner {
        uint256 MAX_TOTAL_FEE = 5000;

        uint256 totalFee = fundFee + lpFee + burnFee + marketingFee + reflowFee;
        require(totalFee <= MAX_TOTAL_FEE, "Total sell fees exceed maximum limit");

        _sellFundFee = fundFee;
        _sellLPFee = lpFee;
        sell_burnFee = burnFee;
        _sellMarketingFee = marketingFee;
        _sellReflowFee = reflowFee;
    }

    function getSellFees() external view returns (
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee,
        uint256 reflowFee
    ) {
        return (_sellFundFee, _sellLPFee, sell_burnFee, _sellMarketingFee, _sellReflowFee);
    }


    function getCurrencyIsEth() external view returns (bool) {
        return currencyIsEth;
    }


    function getMainPair() external view returns (address) {
        return _mainPair;
    }


    function setLastLpBurnTime(uint256 timestamp) external onlyOwner {
        lastLpBurnTime = timestamp;
    }

    function getLastLpBurnTime() external view returns (uint256) {
        return lastLpBurnTime;
    }

    function setLpBurnRate(uint256 rate) external onlyOwner {
        lpBurnRate = rate;
    }

    function getLpBurnRate() external view returns (uint256) {
        return lpBurnRate;
    }

    function setLpBurnFrequency(uint256 frequency) external onlyOwner {
        lpBurnFrequency = frequency;
    }

    function getLpBurnFrequency() external view returns (uint256) {
        return lpBurnFrequency;
    }

    function setTradeFee(uint256 fee) external onlyOwner {
        _tradeFee = fee;
    }

    function getTradeFee() external view returns (uint256) {
        return _tradeFee;
    }

    function setEnableOffTrade(bool status) external onlyOwner {
        enableOffTrade = status;
    }

    function getEnableOffTrade() external view returns (bool) {
        return enableOffTrade;
    }

    function getTotalFundAmountReceive() external view returns (uint256) {
        return totalFundAmountReceive;
    }

    function setFundAddress(address payable addr) external onlyOwner {
        require(addr != address(0), "Invalid address: cannot be zero address");
        fundAddress = addr;
    }

    function getFundAddress() external view returns (address payable) {
        return fundAddress;
    }

    function setBurnLiquidityAddress(address addr) external onlyOwner {
        burnLiquidityAddress = addr;
    }

    function getBurnLiquidityAddress() external view returns (address) {
        return burnLiquidityAddress;
    }

    function setDailyDropPercentage(uint256 percentage) external onlyOwner {
        dailyDropPercentage = percentage;
    }

    function getDailyDropPercentage() external view returns (uint256) {
        return dailyDropPercentage;
    }

    function setOpeningPrice(uint256 price) external onlyOwner {
        openingPrice = price;
    }

    function getOpeningPrice() external view returns (uint256) {
        return openingPrice;
    }

    function setLastUpdateTimestamp(uint256 timestamp) external onlyOwner {
        lastUpdateTimestamp = timestamp;
    }

    function getLastUpdateTimestamp() external view returns (uint256) {
        return lastUpdateTimestamp;
    }

    event MainPairUpdated(address mainPair);
    event CurrencyUpdated(address currency, bool isEth);
    event SwapRouterUpdated(address swapRouter);

}

contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, uint256(~uint256(0)));
    }
}
