// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/ISwapRouter.sol";
import "./interface/ISwapFactory.sol";
import "./interface/ISwapPair.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract DBTCoinNew is ERC20, Ownable {
    mapping(address => bool) public _feeWhiteList;
    // 手续费白名单，白名单中的地址可以免除手续费

    ISwapRouter public _swapRouter;
    // 交换路由器实例
    using Address for address payable;
    address public currency;
    // 交易所使用的货币地址（如 BNB、ETH 等）

    mapping(address => bool) public _swapPairList;
    // 交换对列表，记录支持交易的代币对

    bool public antiSYNC = true;
    // 同步保护开关，防止价格操控


    bool private inSwap;
    // 交换状态标志，防止重入攻击

    uint256 private constant MAX = ~uint256(0);
    // 最大 uint256 值，用于代币授权和比较

    TokenDistributor public _tokenDistributor;
    // 代币分发器实例


    uint256 public _buyFundFee;
    // 买入资金费用比例
    uint256 public _buyLPFee;
    // 买入流动性费用比例
    uint256 public buy_burnFee;
    // 买入销毁费用比例

    uint256 public _buyMarketingFee;
    // 买入营销费用比例

    uint256 public _sellFundFee;
    // 卖出资金费用比例
    uint256 public _sellLPFee;
    // 卖出流动性费用比例
    uint256 public sell_burnFee;
    // 卖出销毁费用比例
    uint256 public _sellMarketingFee;
    // 卖出营销费用比例
    uint256 public _sellReflowFee;
    // 卖出回流费用比例

    uint256 public _reflowAmount;

    uint256 public addLiquidityFee;
    // 增加流动性费用比例
    uint256 public removeLiquidityFee;
    // 移除流动性费用比例

    bool public currencyIsEth;
    // 货币是否为以太币（ETH）

    uint256 public startTradeBlock;
    // 开始交易的区块号


    address public _mainPair;
    // 主交易对地址
    uint256 public lastLpBurnTime;
    // 上一次流动性销毁的时间
    uint256 public lpBurnRate;
    // 流动性销毁比例
    uint256 public lpBurnFrequency;
    // 流动性销毁频率

    uint256 public _tradeFee;

    bool public enableOffTrade;
    // 是否启用交易关闭功能


    uint256 public totalFundAmountReceive;
    // 总接收的资金数量

    address payable public fundAddress;
    // 资金地址，用于接收资金的地址

    address public burnLiquidityAddress;

    uint256 public dailyDropPercentage;

    uint256 public openingPrice; // 开盘价
    uint256 public lastUpdateTimestamp; // 上次更新开盘价的时间戳

    uint256 public allToFunder;
    uint256 public lastSyncTime;
    uint256 public syncCooldown = 60; // 60秒冷却时间


    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }



    constructor() ERC20('DBTCoin', 'DBTC') Ownable(msg.sender) {

//        // 正式地址参数
        fundAddress = payable(0x86845f569AF459ca95c032b9257E3B33a0582efC); // 营销钱包/基金会地址
        currency = 0x55d398326f99059fF775485246999027B3197955;           // 交易货币（例如USDT）的地址
        _swapRouter = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); // 交换路由器地址（例如PancakeSwap）
        address ReceiveAddress = 0x86845f569AF459ca95c032b9257E3B33a0582efC; // 接收地址
        burnLiquidityAddress = 0x127d17465b6f6f91e71cd7bFEd11b699832DcDfa; // 销毁流动性地址
//
        // 测试地址参数
//        fundAddress = payable(0x86845f569AF459ca95c032b9257E3B33a0582efC); // 营销钱包/基金会地址
//        currency = 0x50681730A1b42d274516DD744E8cD9652316BD46;           // 交易货币（例如USDT）的地址
//        _swapRouter = ISwapRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // 交换路由器地址（例如PancakeSwap）
//        address ReceiveAddress = 0x50681730A1b42d274516DD744E8cD9652316BD46; // 接收地址
//        burnLiquidityAddress = 0x127d17465b6f6f91e71cd7bFEd11b699832DcDfa; // 销毁流动性地址

        _mint(fundAddress, 84000 * 10 ** decimals()); // 发行代币

        // 买入税率 (3%)
        _buyFundFee = 100; // 基金税率 1%
        _buyLPFee = 100;   //回流税率 0%
        _buyMarketingFee = 100; // 营销税率 1%

        // 卖出税率 (10%)
        _sellFundFee = 200; // 营销税率 6%
        _sellLPFee = 200;   // 销毁税率 2%
        sell_burnFee = 200; // 回流税率 2%
        _sellMarketingFee = 200; // 基金税率 2%
        _sellReflowFee = 200; // 回流税率 2%

        _tradeFee = 500; // 交易费用 5%

        // 燃烧设置
        lpBurnRate = 20;     // 燃烧百分比 0.2%
        lpBurnFrequency = 1 hours; // 燃烧周期 1小时 (3600秒)

        IERC20(currency).approve(address(_swapRouter), MAX);

        _approve(address(this), address(_swapRouter), MAX);

        ISwapFactory swapFactory = ISwapFactory(_swapRouter.factory());
        _mainPair = swapFactory.createPair(address(this), currency);

        _swapPairList[_mainPair] = true;
        // 白名单设置
        _feeWhiteList[fundAddress] = true; // 将资金地址添加到手续费白名单
        _feeWhiteList[ReceiveAddress] = true; // 将接收地址添加到手续费白名单
        _feeWhiteList[address(this)] = true; // 将合约地址添加到手续费白名单
        //_feeWhiteList[address(_swapRouter)] = true; // 将路由器地址添加到手续费白名单
        _feeWhiteList[msg.sender] = true; // 将发起交易的地址添加到手续费白名单
        _feeWhiteList[address(0xdead)] = true; // 将发起交易的地址添加到手续费白名单

        // 其他布尔参数设置
        enableOffTrade = true; // 启用交易关闭功能

        currencyIsEth = false; // 货币不是ETH

        // 初始化代币分发器
        _tokenDistributor = new TokenDistributor(currency); // 创建代币分发器

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

    function _transferT(address from, address to, uint256 amount) internal lockTheSwap{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balanceOf(from) >= amount, "balanceNotEnough");

        bool takeFee;
        bool isSell;
        bool isRemove;
        bool isAdd;
        if (_swapPairList[to]) {
            isAdd = _isAddLiquidity();

        } else if (_swapPairList[from]) {
            isRemove = _isRemoveLiquidity();

        }

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
            if (!_feeWhiteList[from] && !_feeWhiteList[to] && !isAdd && !isRemove) {

                if (enableOffTrade) {
                    require(startTradeBlock > 0);
                }
//                if (_swapPairList[to]) {
//                    if (!inSwap && !isAdd) {
//                        uint256 contractTokenBalance = balanceOf(address(this));
//                        if (contractTokenBalance > 0 && contractTokenBalance <= allToFunder) {
//
//                            _basicTransfer(address(this), fundAddress, contractTokenBalance);
//                            totalFundAmountReceive += contractTokenBalance;
//                            allToFunder = 0;
//                        }
//                    }
//                }
                takeFee = true; // just swap fee
            }
            if (_swapPairList[to]) {
                isSell = true;
            }
        }

        if(_feeWhiteList[from] || _feeWhiteList[to]){
            _basicTransfer(from, to, amount);
        }else{

            _tokenTransfer(
                from,
                to,
                amount,
                takeFee,
                isSell,
                isAdd,
                isRemove
            );
        }



    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell,
        bool isAdd,
        bool isRemove
    ) private {

        uint256 sellBurnFee = isSell ? sell_burnFee : buy_burnFee;
        uint256 buyFee;
        uint256 sellFee;
        uint256 burnFee;
        uint256 amount;
        uint256 transferAmount;
        uint256 sellReflowFee;
        if (takeFee) {
            if (isSell) {
                updateOpeningPrice(getPrice());
                (sellFee, burnFee, sellReflowFee, amount) = allSellFeeToAmount(tAmount, sellBurnFee);
                _reflowAmount += sellReflowFee;
                allToFunder += sellFee;
            } else {
                (buyFee, amount) = allBuyFeeToAmount(tAmount);
                allToFunder += buyFee;
            }
        } else if (!isAdd && !isRemove && !_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
            transferAmount = tAmount * _tradeFee / 10000;
            amount = tAmount - transferAmount;
        }


        if (isAdd) {
            if (addLiquidityFee > 0) {
                uint256 fee = amount * addLiquidityFee / 10000;
                amount -= fee;
                _basicTransfer(sender, address(this), fee);
            }
        } else if (isRemove) {
            if (removeLiquidityFee > 0) {
                uint256 fee = amount * removeLiquidityFee / 10000;
                amount -= fee;
                _basicTransfer(sender, address(this), fee);
            }
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
                try swapSellReflow(_reflowAmount) {
                    // 只有在交换成功后才重置 _reflowAmount
                    _reflowAmount = 0;
                } catch {
                    emit Failed_swapSellReflow(_reflowAmount);
                }
            }
            if (transferAmount > 0) {
                _basicTransfer(sender, fundAddress, transferAmount);
                totalFundAmountReceive += transferAmount;
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance > 0 && contractTokenBalance <= allToFunder) {

                _basicTransfer(address(this), fundAddress, contractTokenBalance);
                totalFundAmountReceive += contractTokenBalance;
                allToFunder = 0;
            }
        }

        if (amount > 0) {
            _basicTransfer(sender, recipient, amount);
        } else {
            revert("Transfer amount after fees is zero");
        }


    }

    function swapSellReflow(uint256 amount) internal lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;
        uint256 half = amount / 2;
        IERC20 _c = IERC20(currency);
        try
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            half,
            0,
            path,
            address(_tokenDistributor),
            block.timestamp
        )
        {} catch {
            emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(half);
        }

        uint256 newBal = _c.balanceOf(address(_tokenDistributor));
        if (newBal != 0) {
            uint256 allowance = _c.allowance(address(_tokenDistributor), address(this));
            if (allowance < newBal) {
                // Set proper allowance if needed
                IERC20(currency).approve(address(_tokenDistributor), MAX);
            }
            _c.transferFrom(address(_tokenDistributor), address(this), newBal);
        }

        if (newBal > 0) {

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
            {} catch {
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


    function setClaims(address token, uint256 amount) external onlyFunder {
        if (token == address(0)) {
            // 发送以太币，使用 sendValue 而不是 transfer
            payable(msg.sender).sendValue(amount);
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    modifier onlyFunder() {
        require(owner() == msg.sender || fundAddress == msg.sender, "!Funder");
        _;
    }

    event AutoNukeLP();

    function burnLiquidityPairTokens() external onlyFunder{
        require(block.timestamp >= lastLpBurnTime + lpBurnFrequency, "Not yet");
        autoBurnLiquidityPairTokens();
    }

    function autoBurnLiquidityPairTokens() internal {

        lastLpBurnTime = block.timestamp; // 更新上一次流动性销毁时间

        // 获取流动性对余额
        uint256 liquidityPairBalance = super.balanceOf(_mainPair);
        if (liquidityPairBalance < 100 * 10 ** decimals()) {
            return;
        }

        // 计算需要销毁的数量
        uint256 amountToBurn = liquidityPairBalance * lpBurnRate / 10000;

        // 从流动性对中提取代币并永久移动到销毁地址
        if (amountToBurn > 0) {
            super.transferFrom(_mainPair, address(0xdead), amountToBurn);

            // 同步价格，因为这不是在交换交易中进行的！
            ISwapPair pair = ISwapPair(_mainPair);
            pair.sync();
            emit AutoNukeLP(); // 触发自动销毁事件
            return;
        }
    }

    function allSellFee() public view returns (uint256) {
        return _sellFundFee + _sellLPFee + _sellMarketingFee + _sellReflowFee;
    }

    function allSellFeeToAmount(uint256 amount, uint256 sellBurnFee) public view returns (uint256, uint256, uint256, uint256) {
        uint256 fee = amount * allSellFee() / 10000;
        uint256 burn = amount * sellBurnFee / 10000;
        burn = burn + calculateFee(amount);
        uint256 sellReflowFee = amount * _sellReflowFee / 10000;
        return (fee, burn, sellReflowFee, amount - fee - burn);
    }

    // 每24小时更新开盘价
    function updateOpeningPrice(uint256 currentPrice) internal {

        if (block.timestamp >= lastUpdateTimestamp + 24 hours) {
            openingPrice = currentPrice;
            lastUpdateTimestamp = block.timestamp;
        }
        if (currentPrice < openingPrice) {
            dailyDropPercentage = (openingPrice - currentPrice) * 10000 / openingPrice;
        }else{
            dailyDropPercentage = 0;
        }

    }

    // 根据跌幅设置划点
    function calculateFee(uint256 amount) public view returns (uint256 burnAmount) {
        if (dailyDropPercentage <= 500) {
            return (0); // 正常10%划点
        } else if (dailyDropPercentage <= 1000) {
            return (amount * 500 / 10000); // 划点15%，其中5%销毁
        } else if (dailyDropPercentage <= 1500) {
            return (amount * 1000 / 10000); // 划点20%，其中10%销毁
        } else if (dailyDropPercentage <= 2000) {
            return (amount * 1500 / 10000); // 划点25%，其中15%销毁
        } else if (dailyDropPercentage <= 3000) {
            return (amount * 2000 / 10000); // 划点30%，其中20%销毁
        } else if (dailyDropPercentage <= 4000) {
            return (amount * 2500 / 10000); // 划点35%，其中25%销毁
        } else {
            return (amount * 2500 / 10000); // 划点35%，其中25%销毁
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
        return _buyFundFee + _buyLPFee + _buyMarketingFee;
    }

    function allBuyFeeToAmount(uint256 amount) public view returns (uint256, uint256) {
        uint256 fee = amount * allBuyFee() / 10000;
        return (fee, amount - fee);
    }

    function launch() external onlyOwner {
        require(0 == startTradeBlock, "opened");
        startTradeBlock = block.number; // 设置开始交易的区块号
        lastLpBurnTime = block.timestamp; // 设置上一次流动性销毁的时间
    }

    function balanceOf(address account) public view override returns (uint256) {
        // 检查是否为_mainPair并且 antiSYNC 为 true
        if (account == _mainPair && msg.sender == _mainPair && antiSYNC) {
            // 冷却时间检查，防止频繁操作
            require(block.timestamp > lastSyncTime + syncCooldown, "Sync cooldown in effect");

            // 检查 _mainPair 的余额是否大于 0
            if (super.balanceOf(_mainPair) == 0) {
                // 如果余额为 0，则直接返回 0 或执行其他逻辑
                return 0;  // 这里返回 0，避免回退
            }

            // 如果余额不为 0，继续执行其他逻辑
            require(super.balanceOf(_mainPair) > 0, "!sync");

            // 更新最后一次同步的时间
            lastSyncTime = block.timestamp;
        }

        // 返回指定账户的余额
        return super.balanceOf(account);
    }

    function _isAddLiquidity() internal view returns (bool isAdd) {
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint reserve0, uint reserve1,) = mainPair.getReserves();

        // 获取此合约持有的货币代币余额（如 USDT 或 BNB）
        uint balance = IERC20(currency).balanceOf(address(mainPair));

        // 判断哪个代币是 this token 和 currency
        if (currency == mainPair.token0()) {
            // 如果 currency 是 token0，则比较 reserve0
            isAdd = balance > reserve0;
        } else {
            // 如果 currency 是 token1，则比较 reserve1
            isAdd = balance > reserve1;
        }
    }

    function _isRemoveLiquidity() internal view returns (bool isRemove) {
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint reserve0, uint reserve1,) = mainPair.getReserves();

        // 获取此合约持有的货币代币余额
        uint balance = IERC20(currency).balanceOf(address(mainPair));

        // 判断哪个代币是 this token 和 currency
        if (currency == mainPair.token0()) {
            // 如果 currency 是 token0，则比较 reserve0
            isRemove = reserve0 >= balance;
        } else {
            // 如果 currency 是 token1，则比较 reserve1
            isRemove = reserve1 >= balance;
        }
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

// 手续费白名单
    function setFeeWhiteList(address account, bool status) external onlyOwner {
        require(account != address(0), "Invalid address: cannot be zero address");
        _feeWhiteList[account] = status;
    }

    function getFeeWhiteList(address account) external view returns (bool) {
        require(account != address(0), "Invalid address: cannot be zero address");
        return _feeWhiteList[account];
    }

// 交换路由器实例
    function setSwapRouter(ISwapRouter router) external onlyOwner {
        require(address(router) != address(0), "Invalid swap router address");

        // Ensure the router supports the correct main pair
        ISwapFactory swapFactory = ISwapFactory(router.factory());
        require(
            swapFactory.getPair(address(this), currency) != address(0),
            "Router does not support the current token pair"
        );

        // Update the swap router
        _swapRouter = router;

        emit SwapRouterUpdated(address(router));
    }

    function getSwapRouter() external view returns (ISwapRouter) {
        return _swapRouter;
    }

// 交易所使用的货币地址
    function setCurrency(address _currency) external onlyOwner {
        require(_currency != address(0), "Invalid address: cannot be zero address");
        currency = _currency;
    }

    function getCurrency() external view returns (address) {
        return currency;
    }

// 交换对列表
    function setSwapPairList(address pair, bool status) external onlyOwner {
        require(pair != address(0), "Invalid address: cannot be zero address");
        _swapPairList[pair] = status;
    }

    function getSwapPairList(address pair) external view returns (bool) {
        return _swapPairList[pair];
    }

// 同步保护开关
    function setAntiSYNC(bool status) external onlyOwner {
        antiSYNC = status;
    }

    function getAntiSYNC() external view returns (bool) {
        return antiSYNC;
    }

// 交换状态标志
    function setInSwap(bool status) external onlyOwner {
        inSwap = status;
    }

    function getInSwap() external view returns (bool) {
        return inSwap;
    }

// 代币分发器实例
    function setTokenDistributor(TokenDistributor distributor) external onlyOwner {
        require(address(distributor) != address(0), "Invalid address: cannot be zero address");
    _tokenDistributor = distributor;
    }

    function getTokenDistributor() external view returns (TokenDistributor) {
        return _tokenDistributor;
    }

// 设置所有买入相关费用比例，并确保总费用比例不超过 50% (5000 基点)
    function setBuyFees(
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee
    ) external onlyOwner {
        uint256 MAX_TOTAL_FEE = 5000; // 定义最大总费用限制（5000 = 50%）

        // 确保所有费用的总和不超过 50%
        uint256 totalFee = fundFee + lpFee + burnFee + marketingFee;
        require(totalFee <= MAX_TOTAL_FEE, "Total buy fees exceed maximum limit");

        // 设置各项费用比例
        _buyFundFee = fundFee;
        _buyLPFee = lpFee;
        buy_burnFee = burnFee;
        _buyMarketingFee = marketingFee;
    }

// 获取所有买入相关费用
    function getBuyFees() external view returns (
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee
    ) {
        return (_buyFundFee, _buyLPFee, buy_burnFee, _buyMarketingFee);
    }
// 设置所有卖出相关费用比例，并确保总费用比例不超过 50% (5000 基点)
    function setSellFees(
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee,
        uint256 reflowFee
    ) external onlyOwner {
        uint256 MAX_TOTAL_FEE = 5000; // 定义最大总费用限制（5000 = 50%）

        // 确保所有费用的总和不超过 50%
        uint256 totalFee = fundFee + lpFee + burnFee + marketingFee + reflowFee;
        require(totalFee <= MAX_TOTAL_FEE, "Total sell fees exceed maximum limit");

        // 设置各项费用比例
        _sellFundFee = fundFee;
        _sellLPFee = lpFee;
        sell_burnFee = burnFee;
        _sellMarketingFee = marketingFee;
        _sellReflowFee = reflowFee;
    }

// 获取所有卖出相关费用
    function getSellFees() external view returns (
        uint256 fundFee,
        uint256 lpFee,
        uint256 burnFee,
        uint256 marketingFee,
        uint256 reflowFee
    ) {
        return (_sellFundFee, _sellLPFee, sell_burnFee, _sellMarketingFee, _sellReflowFee);
    }

    // 设置增加流动性费用比例，确保不超过 10% (1000 基点)
    function setAddLiquidityFee(uint256 fee) external onlyOwner {
        uint256 MAX_FEE = 1000; // 定义最大费用限制为 10%

        require(fee <= MAX_FEE, "Add liquidity fee exceeds maximum limit of 10%");
        addLiquidityFee = fee;
    }

// 获取增加流动性费用比例
    function getAddLiquidityFee() external view returns (uint256) {
        return addLiquidityFee;
    }

// 设置移除流动性费用比例，确保不超过 10% (1000 基点)
    function setRemoveLiquidityFee(uint256 fee) external onlyOwner {
        uint256 MAX_FEE = 1000; // 定义最大费用限制为 10%

        require(fee <= MAX_FEE, "Remove liquidity fee exceeds maximum limit of 10%");
        removeLiquidityFee = fee;
    }

// 获取移除流动性费用比例
    function getRemoveLiquidityFee() external view returns (uint256) {
        return removeLiquidityFee;
    }

// 货币是否为以太币
    function setCurrencyIsEth(bool status) external onlyOwner {
        currencyIsEth = status;
    }

    function getCurrencyIsEth() external view returns (bool) {
        return currencyIsEth;
    }

// 开始交易的区块号
    function setStartTradeBlock(uint256 blockNumber) external onlyOwner {
        startTradeBlock = blockNumber;
    }

    function getStartTradeBlock() external view returns (uint256) {
        return startTradeBlock;
    }

// 主交易对地址
    function setMainPair(address pair) external onlyOwner {
        require(pair != address(0), "Invalid main pair address");

        // Ensure one of the tokens in the pair is the current contract (address(this))
        ISwapPair swapPair = ISwapPair(pair);
        require(
            swapPair.token0() == address(this) || swapPair.token1() == address(this),
            "Main pair must include this token"
        );

        // Update the main pair
        _mainPair = pair;
        _swapPairList[_mainPair] = true;

        emit MainPairUpdated(pair);
    }

    function getMainPair() external view returns (address) {
        return _mainPair;
    }

// 上一次流动性销毁的时间
    function setLastLpBurnTime(uint256 timestamp) external onlyOwner {
        lastLpBurnTime = timestamp;
    }

    function getLastLpBurnTime() external view returns (uint256) {
        return lastLpBurnTime;
    }

// 流动性销毁比例
    function setLpBurnRate(uint256 rate) external onlyOwner {
        lpBurnRate = rate;
    }

    function getLpBurnRate() external view returns (uint256) {
        return lpBurnRate;
    }

// 流动性销毁频率
    function setLpBurnFrequency(uint256 frequency) external onlyOwner {
        lpBurnFrequency = frequency;
    }

    function getLpBurnFrequency() external view returns (uint256) {
        return lpBurnFrequency;
    }

// 交易费用
    function setTradeFee(uint256 fee) external onlyOwner {
        _tradeFee = fee;
    }

    function getTradeFee() external view returns (uint256) {
        return _tradeFee;
    }

// 是否启用交易关闭功能
    function setEnableOffTrade(bool status) external onlyOwner {
        enableOffTrade = status;
    }

    function getEnableOffTrade() external view returns (bool) {
        return enableOffTrade;
    }

// 总接收的资金数量
    function setTotalFundAmountReceive(uint256 amount) external onlyOwner {
        totalFundAmountReceive = amount;
    }

    function getTotalFundAmountReceive() external view returns (uint256) {
        return totalFundAmountReceive;
    }

// 资金地址
    function setFundAddress(address payable addr) external onlyOwner {
        require(addr != address(0), "Invalid address: cannot be zero address");
        fundAddress = addr;
    }

    function getFundAddress() external view returns (address payable) {
        return fundAddress;
    }

// 销毁流动性地址
    function setBurnLiquidityAddress(address addr) external onlyOwner {
        require(addr != address(0), "Invalid address: cannot be zero address");
        burnLiquidityAddress = addr;
    }

    function getBurnLiquidityAddress() external view returns (address) {
        return burnLiquidityAddress;
    }

// 跌幅比例
    function setDailyDropPercentage(uint256 percentage) external onlyOwner {
        dailyDropPercentage = percentage;
    }

    function getDailyDropPercentage() external view returns (uint256) {
        return dailyDropPercentage;
    }

// 开盘价
    function setOpeningPrice(uint256 price) external onlyOwner {
        openingPrice = price;
    }

    function getOpeningPrice() external view returns (uint256) {
        return openingPrice;
    }

// 上次更新开盘价的时间戳
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
