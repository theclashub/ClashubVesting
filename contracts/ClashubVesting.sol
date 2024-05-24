// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* lodos2005
  
   _____ _                _____ _    _ _    _ ____  
  / ____| |        /\    / ____| |  | | |  | |  _ \ 
 | |    | |       /  \  | (___ | |__| | |  | | |_) |
 | |    | |      / /\ \  \___ \|  __  | |  | |  _ < 
 | |____| |____ / ____ \ ____) | |  | | |__| | |_) |
  \_____|______/_/    \_\_____/|_|  |_|\____/|____/ 
                                                    
  WEBSITE: WWW.CLASHUB.IO 

  Clashub Vesting Contract

*/

interface IBEP20 {
 
  /**
   * @dev Moves `amount` tokens from the caller's account to `recipient`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transfer(address recipient, uint256 amount) external returns (bool);

  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

}


contract ClashubVesting {
    struct Vesting {
        uint256 amount;
        uint256 step;
        bool isClaimed;
    }

    mapping(address => Vesting[]) public VestingInfo;
    IBEP20 public Token;
    mapping(uint step => uint unixtime)  public StepDates;
    uint256 public MaxStep;

    uint128 public OwnerCount = 5;
    uint128 public MinApproved = 3;
    mapping(uint256 => address) public Owners;
    //we have 6 function for owner
    // 0 changeTokenAddress_Approval;
    // 1 setStep_Approval;
    // 2 createVestingOne_Approval;
    // 3 createVestingMulti_Approval;
    // 4 deleteVesting_Approval;
    // 5 changeOwnerAddress_Approval;
    mapping(uint256 functionID => mapping(address ownerAddress => bool isApproved)) public ApprovalOf;
    bool public InitPriv=true;

    //onlyOwner modifier
    modifier onlyOwner() {
        bool checkOwner;        
        uint256 _OwnerCount = OwnerCount;

        for (uint i=0; i<_OwnerCount; i++) 
        {
            if (Owners[i]==msg.sender) {checkOwner=true;break;} 
        }
        require(checkOwner,"You are not admin");
        _;
    }

    modifier onlyApproved(uint256 _functionID) {
        bool checkOwner;
        uint256 approved=0;
        uint256 _OwnerCount = OwnerCount;   
        for (uint i=0; i<_OwnerCount; i++) 
        {
            if (ApprovalOf[_functionID][Owners[i]]){
                approved++;
            }
        }
        if (InitPriv) approved=_OwnerCount;     
        require(approved>=MinApproved,"Function not approved");
        _;
    } 


    constructor(address _tokenAddress, address[] memory _owners ) {
        Token = IBEP20(_tokenAddress);
        require(_owners.length==OwnerCount,"You Have 5 Owners");
        for (uint i=0; i<_owners.length; i++) 
        {
            Owners[i]=_owners[i];
        }
    }
 
    function disable_initpriv() external onlyOwner{
        //we not need to 5 owners approved
        InitPriv=false;
    }

    function addApprove(uint256 _functionID,bool _approved) external onlyOwner{
       ApprovalOf[_functionID][msg.sender]=_approved;
    }
    

    function changeTokenAddress(address _newToken) external onlyOwner onlyApproved(0){
        Token = IBEP20(_newToken);
    }

    function setStep(uint256 _step, uint256 _unixtime) external onlyOwner onlyApproved(1){
        StepDates[_step]=_unixtime;
        if (MaxStep<_step)
            MaxStep=_step;
    }
 
    function createVestingOne(
        address  _beneficiaries,
        uint256  _amounts,
        uint256 _step,
        bool _isClaimed
    ) external onlyOwner onlyApproved(2){
        VestingInfo[_beneficiaries].push(
            Vesting({amount: _amounts, step: _step, isClaimed: _isClaimed})
        );
    }

    function createVestingMulti(
        address[] memory _beneficiaries,
        uint256[] memory _amounts,
        uint256 _step
    ) external onlyOwner onlyApproved(3){
        require(
            _beneficiaries.length == _amounts.length,
            "Invalid input length"
        );

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            VestingInfo[_beneficiaries[i]].push(
                Vesting({amount: _amounts[i], step: _step, isClaimed: false})
            );
        }
    }

    function deleteVesting(address[] memory _beneficiaries) external onlyOwner onlyApproved(4){
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            delete VestingInfo[_beneficiaries[i]];
        }
    }

    function changeOwnerAddress(address _oldOwner, address _newOwner) external onlyOwner onlyApproved(5){
        //check oldowner is owner,

        bool checkOwner;
        uint256 _oldadminID;        
        uint256 _OwnerCount = OwnerCount;

        for (uint i=0; i<_OwnerCount; i++) 
        {
            if (Owners[i]==_oldOwner) {
                _oldadminID=i;
                checkOwner=true;
                break;
            } 
        }
        require(checkOwner,"_oldOwner is not admin");

        checkOwner=false;
        //check newowner is not owner,
         for (uint i=0; i<_OwnerCount; i++) 
         {
            if (Owners[i]==_newOwner) 
            {
                checkOwner=true;
                break;
            } 
         }
         require(!checkOwner,"_newOwner is admin");  //check newowner is not admin
         Owners[_oldadminID]=_newOwner;
     }


    
    function getTotalVesting() external view returns (Vesting[] memory) {
        return this.getTotalVesting(msg.sender);
    }
    function getTotalVesting(
        address _beneficiary
    ) external view returns (Vesting[] memory) {
        return VestingInfo[_beneficiary];
    }

    function getTotalClaimed() external view returns (uint256) {
        return this.getTotalClaimed(msg.sender);
    }

    function getTotalClaimed(
        address _beneficiary
    ) external view returns (uint256) {
        uint256 totalClaimed;
        for (uint256 i = 0; i < VestingInfo[_beneficiary].length; i++) {
            if (VestingInfo[_beneficiary][i].isClaimed) {
                totalClaimed += VestingInfo[_beneficiary][i].amount;
            }
        }
        return totalClaimed;
    }

    function getRemainingVesting() external view returns (Vesting[] memory) {
        return this.getRemainingVesting(msg.sender);
    }
    function getRemainingVesting(
        address _beneficiary
    ) external view returns (Vesting[] memory) {
        Vesting[] memory schedules = VestingInfo[_beneficiary];
        uint256 remainingCount;
        for (uint256 i = 0; i < schedules.length; i++) {
            if (!schedules[i].isClaimed) {
                remainingCount++;
            }
        }

        Vesting[] memory remainingVesting = new Vesting[](remainingCount);
        uint256 index;
        for (uint256 i = 0; i < schedules.length; i++) {
            if (!schedules[i].isClaimed) {
                remainingVesting[index] = schedules[i];
                index++;
            }
        }

        return remainingVesting;
    }


    function getStep(uint256 _step) external view returns (uint256) {
        return StepDates[_step];
    }

    function getStep() public view returns (uint256) {
        uint256 retstep=0;
        uint256 _maxstep=MaxStep;
        for (uint i=0; i<_maxstep+1; i++) 
        {
            if (StepDates[i]>block.timestamp)
                break;
            retstep = i;
        }
        return retstep;
    }


    function claim(uint256 _step) external {
        Vesting[] storage schedules = VestingInfo[msg.sender];
        require(getStep() >= _step, "Cannot claim tokens for future steps"); // Ensure step is not in the future

        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].step == _step && !schedules[i].isClaimed) {
                schedules[i].isClaimed = true;
                Token.transfer(msg.sender, schedules[i].amount);
                break; // Only claim for one schedule per step
            }
        }
    }
}


