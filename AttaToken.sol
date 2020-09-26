pragma solidity ^0.5.10;
// pragma experimental ABIEncoderV2;
import './utils/utils.sol';


/**
 * @title Ownable 代币的拥有者
 * @dev 这个合约主要是指明合约创建人为代币的创建者，还包括授权控制功能，简化“用户权限”.
 */

contract Ownable{
    //"拥有者"
    address public owner;
    /**
      * @dev 把创建合约的人作为初始的“拥有者”，即最高权限账号（account）.
      */
    constructor() public{
        owner = msg.sender;
    }

    /**
      * @dev 给仅能拥有者进行操作，提供判定方法.
      */
    modifier onlyOwner(){
        require(msg.sender == owner, "仅owner调用！");
        //这一行表示继承此合约中使用
        _;
    }

    /**
    * @dev 转让拥有者身份
    * @param newOwner 新的拥有者的.
    */
    function transferOwnership(address newOwner) public onlyOwner{
        //先确保新用户不是0x0地址
        require(newOwner != address(0), "不能给地址0转移owner");
        owner = newOwner;
    }
}

/**
 * @title Pausable 中断
 * @dev 实现紧急停止机制
 */
contract Pausable is Ownable{
    event Pause();
    event Unpause();

    bool public paused = false;

    /**
    * @dev Modifier to make a function callable only when the contract is not paused.
    * @dev 限制条件：函数只能是在合约未停止情况下执行.
    */
    modifier whenNotPaused(){
        require(!paused, "Must be used without pausing");
        _;
    }

    /**
    * @dev Modifier to make a function callable only when the contract is paused.
    * @dev 函数只能在停止条件下执行
    */
    modifier whenPaused(){
        require(paused, "Must be used under pause");
        _;
    }

    /**
    * @dev called by the owner to pause, triggers stopped state
    * @dev 只能由代币管理者进行停止
    *
    */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
    * @dev called by the owner to unpause, returns to normal state
    * @dev 只能是代币管理者进行重开
    */
    function unpause() public onlyOwner whenPaused{
        paused = false;
        emit Unpause();
    }
}

contract BasicToken is ERC721, Ownable {
    using SafeMath for uint;
    /**
    * @dev 防止短地址攻击，具体可看博客ERC20文章
    * @dev 凡是涉及转账交易（合约调用）都需要加上这一限制
    */
    modifier onlyPayloadSize(uint size){
        //msg.data就是data域（calldata）中的内容，一般来说都是4（函数名）+32（转账地址）+32（转账金额）=68字节
        //短地址攻击简单来说就是转账地址后面为0但故意缺省，导致金额32字节前面的0被当做地址而后面自动补0导致转账金额激增。
        //参数size就是除函数名外的剩下字节数
        //解决方法：对后面的的字节数的长度限制要求
        require(!(msg.data.length < size+4), "Invalid short address");
        _;
    }
    /** 
    * TODO：求证针对不可分割的资产型的通证的tranfer，是不是不需要防范短地址攻击
    function transfer(address _to, uint256 _tokenId) require onlyPayloadSize(32*2){
    }
    */

    function transfer(address _to, uint256 _tokenId) {
        transferFrom(msg.sender, _to, _tokenId);
    }

}

/** 
 * @dev 建立黑名单
 * 情况一：（实例代码所述）
 * 黑名单是全合约通用的，如果有任何一个CCP持有者想将某人加入黑名单，则需要有数据保全和制约
 * 1. 投票进出黑名单
 * 2. 随意进出黑名单，但保留收益权（仅对资质通证 ATTAToken 有意义，对权益通证没意义）
 * 3. 随意进出黑名单，由合约接收收益权，申诉期过后，所有CCP均分期间收益，收益权释放给资质持有人
 * 针对申述，黑名单合约内投票
 * 情况二：
 * 黑名单是隶属于CCP的，只有合约拥有者能全合约封禁账户
 */
contract BlackList is Ownable, BasicToken{
    //黑名单映射
    mapping(address => bool) isBlackListed;
    //事件
    event DestroyedBlackFunds(address _blackListedUser, uint _balance);
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);


    //允许其他合约调用此黑名单(external)，查看此人是否被列入黑名单
    function getBlackListStatus(address _maker) external view returns(bool){
        return isBlackListed[_maker];
    }

    //获取当前代币的Owner
    function getOwner() external view returns(address){
        return owner;
    }
    //增加黑名单
    function addBlackList(address _evilUser) public onlyOwner{
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    //去除某人黑名单
    function removeBlackList(address _clearUser) public onlyOwner{
        isBlackListed[_clearUser] = false;
        emit RemovedBlackList(_clearUser);
    }
}




// 主体通证 资质通证，表示持有者具备某种资格。由发行者自定义资格的内容和权限，并在自己的信息系统中应用
// ToDo: 取名
contract AttaToken is BasicToken, Pausable {
    constructor (string memory name, string memory symbol) ERC721(name, symbol) public{
    // AttaToken 的合约发布者，在初始化的时候将发行一批合作者通证，并由owner全部持有；并根据市场行情和平台价值于各种途径转让
    // AttaToken 的转让可以被认为是另一种形式的ICO。只是该过程是一个持续切长期的过程。Token的稀缺性并不会妨碍Crypto Atta已有项目的资源
    
    // TODO: 发行一批平台通证（CCP），由owner持有，增发需要有策略支持
    // TODO: 待定增发CCP通证策略

    }

    uint256[] public ccpIdList;
    struct attaData {

    }
    // 建立tokenId和数组序号的对应关系。通过tokenId找到通证扩展信息的数组序号
    mapping(uint256 => uint) getAttaDataIndexByTokenId;

    function transfer(address _to, uint256 _tokenId) public when whenNotPaused {
        // 排除黑名单
        require(!isBlackListed[msg.sender],  "不允许黑名单用户转出通证");
        require(!isBlackListed[_to],  "不允许黑名单用户接受");
        return super.transfer(_to, _tokenId);
    }

    function totalSupply() public view returns(uint) {
        return _totalSupply;
    }

    // 拥有CCP资格的人，发行自己的平台内应用通证
    // 还是取消平台发行，每个人都可以自由申请发行？
    function issue(uint256 _tokenId) public whenNotPaused returns(uint256) {
        // 判定sender是否有其声称的AttaToken的所有权
        require(msg.sender == ownerOf(_tokenId), "您没有该通证的所有权");
        // ToDo: 判断是否是CCP 的 id
        // ToDO: 随机生成新发型的通证的id
        _safeMint()
    }
}
