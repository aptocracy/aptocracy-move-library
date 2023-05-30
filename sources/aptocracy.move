
module org_lib_addr::aptocracy {
  use org_lib_addr::organization;
  use org_lib_addr::proposals;
  use org_lib_addr::treasury;
  use std::string::{String,utf8};
  use aptos_token::token::{Self};
  use aptos_framework::account::{Self, SignerCapability};
  use std::bcs;
  use aptos_framework::coin;
  use aptos_framework::aptos_coin::AptosCoin;
  use std::signer;
  use std::option::{Self, Option};
  use std::timestamp;
  use std::vector;
  use std::type_info::{Self, TypeInfo};
  use std::string;
  use std::math64;
  #[test_only]
  use std::transaction_context;



  struct Aptocracy has key {
    signer_capability: SignerCapability,
  }

  struct AptocracyOrganization has store, copy, drop {
    treasury_count: u32,
    aptocracy_address:address,
    main_treasury: Option<address>

  }

  struct AptocracyMember has store,copy,drop {
    proposal_created: u32,
    aptocracy_address:address

  }


  struct AptocracyGovernance has store,copy,drop {
    valid_from: u64,
    valid_to: Option<u64>,
    aptocracy_address:address

  }

  struct AptocracyTreasury has store, copy, drop {
    governance_id: u64,
    aptocracy_address:address
  }

  struct AptocracyProposal has store, copy, drop {
    discussion_link: String,
    treasury_address: address,
    aptocracy_address:address,
    proposal_type: String,
    number_of_votes: u64,
    governance_id: u64

  }


  //Org types
  const ROLE_BASED: u64 = 0;
  const TOKEN_BASED: u64 = 1;
  const NFT_BASED: u64 = 2;


  //Actions
  //Default org actions
  const CHANGE_GOVERNANCE_CONFIG:u64 =0;
  const CREATE_GOVERNANCE:u64 =1;
  const INVITE_MEMBER:u64 = 2;
  const UPDATE_MAIN_GOVERNANCE:u64 = 3;
  //Aptocracy actions
  const CREATE_TREASURY:u64 =4;
  const SUPPORT_ORG:u64 =5;
  const CAST_VOTE:u64 = 6;
  const CANCEL_PROPOSAL:u64 = 7;
  const FINALIZE_VOTES:u64 = 8;
  const RELINQUISH_VOTE:u64 = 9;
  const CREATE_PROPOSAL:u64 = 10;
  const CREATE_CHANGE_GOVERNANCE_CONFIG:u64=11;
  const UPDATE_MAIN_TREASURY:u64=12;



  //Errors
  ///Aptocracy account doesnt exist
  const EACCOUNT_NOT_EXIST: u64 = 0;
  //Voter weight can not be zero 
  const ENOT_ENOUGH_VOTER_WEIGHT: u64 = 1;
  ///Main governance not defined
  const EMAIN_GOVERNANCE_NOT_DEFINED:u64=2;
  ///Invalid change governance config parameters
  const EINVALID_PARAMETERS:u64=3;
  ///Change configuration for given governance already defined in this proposal
  const EINVALID_CHANGE_GOVERNANCE_PARAMS:u64=4;
  ///Invalid amount of change governance options
  const EINVALID_CHANGE_GOVERNANCE_OPTIONS:u64=5;
  ///Transfer proposal must have only one option
  const EWRONG_OPTION_LENGHT: u64 = 6;
  ///Organization must have only one owner
  const EDUPLICATE_OWNER: u64 = 7;
  ///Main governance can not be updated without proposal
  const EMAIN_GOV_ALREADY_EXISTS: u64 = 8;
  ///Main treasury can not be updated without proposal
  const EMAIN_TREASURY_ALREADY_EXISTS: u64 = 9;
  ///Given treasury is not related to this proposal
  const EINVALID_TREASURY: u64 = 10;
  ///Quorum must be between 0 and 100
  const EWRONG_QUORUM: u64 = 11;
  ///Invalid proposal governance
  const EINVALID_GOVERNANCE: u64 = 12;


  //With options - not supported for typescript clients for now (use nft/non-nft create org functions)
  public entry fun create_organization<CoinType>(account: &signer, name: String,  org_type: u64, role_names:vector<String>, role_weights: vector<u64>,role_actions: vector<vector<u64>>,owner_role: String, total_nft_votes: Option<u64>, creator_address: Option<address>, collection_name: Option<String>, invite_only: bool, default_role: String) {
    let account_address = signer::address_of(account);
    let seeds: vector<u8> = bcs::to_bytes<String>(&name);
    let (res_signer, res_cap) = account::create_resource_account(account, seeds);
    
    coin::register<AptosCoin>(&res_signer);
    token::opt_in_direct_transfer(&res_signer, true);

     move_to(
      &res_signer,
      Aptocracy {
        signer_capability: res_cap,
        }
    );

    let org_metadata = AptocracyOrganization {
      treasury_count: 0,
      aptocracy_address:signer::address_of(&res_signer),
      main_treasury: option::none(),
    };
    organization::create_organization<AptocracyOrganization, AptocracyGovernance, AptocracyMember, CoinType>(
      &res_signer, 
      account_address,
      name, 
      org_type, 
      role_names, 
      role_weights, 
      role_actions, 
      owner_role, 
      total_nft_votes, 
      creator_address,
      collection_name,
      org_metadata,
      AptocracyMember {
        proposal_created: 0,
        aptocracy_address:signer::address_of(&res_signer)
      },
      invite_only,
      default_role
    );

  }

  public entry fun create_non_nft_organization<CoinType>(account: &signer, name: String,  org_type: u64, role_names:vector<String>, role_weights: vector<u64>, role_actions: vector<vector<u64>>,  owner_role: String, invite_only: bool, default_role: String) {
    let account_address = signer::address_of(account);
    let seeds: vector<u8> = bcs::to_bytes<String>(&name);
    let (res_signer, res_cap) = account::create_resource_account(account, seeds);
    
    coin::register<AptosCoin>(&res_signer);
    token::opt_in_direct_transfer(&res_signer, true);

        move_to(
      &res_signer,
      Aptocracy {
        signer_capability: res_cap,
      }
    );


    let org_metadata = AptocracyOrganization {
      treasury_count: 0,
      aptocracy_address:signer::address_of(&res_signer),
      main_treasury: option::none(),


    };
    organization::create_organization<AptocracyOrganization, AptocracyGovernance, AptocracyMember, CoinType>(
      &res_signer, 
      account_address,
      name, 
      org_type, 
      role_names, 
      role_weights, 
      role_actions, 
      owner_role, 
      option::none(), 
      option::none(),
      option::none(),
      org_metadata,
      AptocracyMember {
        proposal_created: 0,
        aptocracy_address:signer::address_of(&res_signer)
      },
      invite_only,
      default_role
    );

  }

  public entry fun create_nft_organization<CoinType>(account: &signer, name: String,  role_names:vector<String>, role_weights: vector<u64>,role_actions: vector<vector<u64>>,owner_role: String, invite_only: bool, default_role: String, total_nft_votes: u64, creator_address: address, collection_name: String,) {
    let account_address = signer::address_of(account);
    let seeds: vector<u8> = bcs::to_bytes<String>(&name);
    let (res_signer, res_cap) = account::create_resource_account(account, seeds);
    
    coin::register<AptosCoin>(&res_signer);
    token::opt_in_direct_transfer(&res_signer, true);

     move_to(
      &res_signer,
      Aptocracy {
        signer_capability: res_cap,
        }
    );

    let org_metadata = AptocracyOrganization {
      treasury_count: 0,
      aptocracy_address:signer::address_of(&res_signer),
      main_treasury: option::none(),
    };
    organization::create_organization<AptocracyOrganization, AptocracyGovernance, AptocracyMember, CoinType>(
      &res_signer, 
      account_address,
      name, 
      NFT_BASED, 
      role_names, 
      role_weights, 
      role_actions, 
      owner_role, 
      option::some(total_nft_votes), 
      option::some(creator_address),
      option::some(collection_name),
      org_metadata,
      AptocracyMember {
        proposal_created: 0,
        aptocracy_address:signer::address_of(&res_signer)
      },
      invite_only,
      default_role
    );


 

  }

  public entry fun create_governance(creator: &signer, organization_address: address, max_voting_time: u64, approval_quorum: u64, quorum: u64, early_tipping: bool) {
    assert!(exists<Aptocracy>(organization_address), EACCOUNT_NOT_EXIST);
    organization::create_governance<AptocracyOrganization, AptocracyMember, AptocracyGovernance>(creator,organization_address, max_voting_time, approval_quorum, quorum, early_tipping, AptocracyGovernance {
      valid_from: timestamp::now_seconds(),
      valid_to: option::none(),
      aptocracy_address:organization_address
    },);
  }

  public entry fun update_main_org_governance(payer: &signer, organization_address: address, governance_id: u64) {
     assert!(exists<Aptocracy>(organization_address), EACCOUNT_NOT_EXIST);
     assert!(option::is_none<u64>(&organization::get_main_governance<AptocracyOrganization>(organization_address)),EMAIN_GOV_ALREADY_EXISTS);
     organization::update_main_governance<AptocracyOrganization, AptocracyGovernance, AptocracyMember>(signer::address_of(payer), organization_address, governance_id);
  }

  public entry fun update_main_org_treasury(payer: &signer, organization_address: address, treasury_address: address) {
     assert!(exists<Aptocracy>(organization_address), EACCOUNT_NOT_EXIST);
     let org_metadata = organization::get_organization_metadata<AptocracyOrganization>(organization_address);
     assert!(option::is_none(&org_metadata.main_treasury), EMAIN_TREASURY_ALREADY_EXISTS);
     assert!(treasury::check_if_treasury_exists<AptocracyTreasury>(treasury_address), EACCOUNT_NOT_EXIST);
     organization::check_permission<AptocracyOrganization, AptocracyMember>(organization_address, signer::address_of(payer), UPDATE_MAIN_TREASURY);

    let updated_org_metadata = org_metadata;
    updated_org_metadata.main_treasury = option::some<address>(treasury_address);
    organization::update_org_metadata<AptocracyOrganization>(organization_address, updated_org_metadata);
  }


  public entry fun create_treasury<CoinType>(creator: &signer, account_address: address, governance_id: u64) acquires Aptocracy {
    assert!(exists<Aptocracy>(account_address), EACCOUNT_NOT_EXIST);
    let org_metadata = organization::get_organization_metadata<AptocracyOrganization>(account_address);
    let aptocracy = borrow_global<Aptocracy>(account_address);
    organization::check_if_governance_exist<AptocracyGovernance>(account_address, governance_id);
    organization::check_permission<AptocracyOrganization, AptocracyMember>(account_address, signer::address_of(creator), CREATE_TREASURY);
    let org_signer = account::create_signer_with_capability(&aptocracy.signer_capability);

    treasury::create_treasury<AptocracyTreasury, CoinType>(&org_signer, account_address, org_metadata.treasury_count, AptocracyTreasury {
      governance_id,
      aptocracy_address:org_metadata.aptocracy_address
    });

    if(!proposals::check_if_resource_is_registered<AptocracyProposal>(signer::address_of(&org_signer))){
    proposals::initialize<AptocracyProposal>(&org_signer);
    };
    let updated_org_metadata = org_metadata;
    updated_org_metadata.treasury_count = updated_org_metadata.treasury_count + 1;
    organization::update_org_metadata<AptocracyOrganization>(account_address, updated_org_metadata);
  }

  public entry fun support_org<CoinType>(payer: &signer, account_address: address, deposit_amount: u64, treasury_address: address) {
      assert!(exists<Aptocracy>(account_address), EACCOUNT_NOT_EXIST);
      let member_address = signer::address_of(payer);
      if(!organization::is_invite_only<AptocracyOrganization>(account_address)) {
        if(!organization::is_member<AptocracyOrganization, AptocracyMember>(account_address, member_address)) {
          organization::join_organization<AptocracyOrganization, AptocracyMember>(payer, account_address,  AptocracyMember {
            proposal_created: 0,
            aptocracy_address:account_address
          });
        };
      };
      organization::check_permission<AptocracyOrganization, AptocracyMember>(account_address, member_address ,SUPPORT_ORG);
      treasury::deposit<AptocracyTreasury, CoinType>(payer, deposit_amount, treasury_address);
      
  }


  public entry fun withdraw_funds<CoinType>(payer: &signer, account_address: address, withdraw_amount: u64, treasury_address: address) {
      assert!(exists<Aptocracy>(account_address), EACCOUNT_NOT_EXIST);
      let member_address = signer::address_of(payer);
      assert!(organization::is_member<AptocracyOrganization, AptocracyMember>(account_address, member_address), EACCOUNT_NOT_EXIST);
      treasury::withdraw<AptocracyTreasury, AptosCoin>(payer, withdraw_amount, treasury_address);
   
  }

  public entry fun invite_aptocracy_member(payer: &signer,aptocracy_account: address,member_address: address, role: String) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);

    organization::invite_member<AptocracyOrganization, AptocracyMember>(
      payer,
      aptocracy_account,
      member_address,
      role,
      AptocracyMember {
        proposal_created: 0,
        aptocracy_address:aptocracy_account
      },
    )
  }

  public entry fun accept_aptocracy_membership(payer: &signer,aptocracy_account: address) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    organization::accept_membership<AptocracyOrganization, AptocracyMember>(
      payer,
      aptocracy_account,
    )
  }

  public entry fun cast_vote(voter: &signer, aptocracy_account: address, treasury_address: address, proposal_id: u64, token_names: vector<String>, token_property_versions: vector<u64>, vote_options: vector<String> ) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    //check permission for cast vote
    organization::check_permission<AptocracyOrganization, AptocracyMember>(aptocracy_account, signer::address_of(voter),CAST_VOTE);
    let org_type = organization::get_organization_type<AptocracyOrganization>(aptocracy_account);
    //calculate vote_weight for member
    let voter_weight: u64 = 0;
    //role based  - role weight
    if(org_type == ROLE_BASED) {
      let (role_weight, _role_actions) = organization::get_member_role_info<AptocracyOrganization, AptocracyMember>(aptocracy_account,signer::address_of(voter));
      voter_weight = role_weight;
    };
    //nft based - number of nfts
    if(org_type == NFT_BASED) {
      let (name, creator) = organization::get_governing_collection_info<AptocracyOrganization>(aptocracy_account);
      let index = 0;
      while(index < vector::length<String>(&token_names)) {
        let token_name = *vector::borrow<String>(&token_names, index);
        let property_version = *vector::borrow<u64>(&token_property_versions, index);
        let token_id = token::create_token_id_raw(creator, name, token_name, property_version);
        assert!(token::balance_of(signer::address_of(voter), token_id) == 1,0);
        voter_weight = voter_weight + 1;
        index = index + 1;
      };
    };
    //token based - deposited amount
    if(org_type == TOKEN_BASED) {
      let proposal_metadata = proposals::get_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id);
      assert!(proposal_metadata.treasury_address == treasury_address, EINVALID_TREASURY);
      voter_weight = treasury::get_deposited_amount_for_address_for_timestamp<AptocracyTreasury>(treasury_address,signer::address_of(voter), 
      proposals::get_proposal_creation_time<AptocracyProposal>(aptocracy_account, proposal_id));
    };

    assert!(voter_weight > 0, ENOT_ENOUGH_VOTER_WEIGHT);
    proposals::vote_for_proposal<AptocracyProposal>(
      voter,
      aptocracy_account,
      proposal_id,
      voter_weight,
      vote_options
    );

    let updated_proposal_metadata = proposals::get_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id);
    updated_proposal_metadata.number_of_votes = updated_proposal_metadata.number_of_votes + 1;
    proposals::update_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id, updated_proposal_metadata);
  }

  public entry fun cancel_aptocracy_proposal(payer: &signer, aptocracy_account: address, proposal_id: u64) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    organization::check_permission<AptocracyOrganization, AptocracyMember>(aptocracy_account, signer::address_of(payer),CANCEL_PROPOSAL);
    proposals::cancel_proposal<AptocracyProposal>(aptocracy_account, proposal_id);
  }

  public entry fun finalize_votes_for_aptocracy_proposal(payer: &signer, aptocracy_account: address, proposal_id: u64) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    organization::check_permission<AptocracyOrganization, AptocracyMember>(aptocracy_account, signer::address_of(payer),FINALIZE_VOTES);
    proposals::finalize_votes<AptocracyProposal>(aptocracy_account, proposal_id);
  }

  public entry fun relinquish_vote(voter: &signer, aptocracy_account: address, proposal_id: u64) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    organization::check_permission<AptocracyOrganization, AptocracyMember>(aptocracy_account, signer::address_of(voter),RELINQUISH_VOTE);
    proposals::relinquish_vote<AptocracyProposal>(voter, aptocracy_account, proposal_id);
    let updated_proposal_metadata = proposals::get_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id);
    updated_proposal_metadata.number_of_votes = updated_proposal_metadata.number_of_votes - 1;
    proposals::update_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id, updated_proposal_metadata);
  }

  public entry fun execute_proposal(sender:&signer,proposal_id:u64,proposal_parameters:vector<vector<u8>>,option:String,
    aptocracy_account:address){
    proposals::execute_proposal_option<AptocracyProposal>(sender,aptocracy_account,proposal_id,option,proposal_parameters);
  }

  public entry fun create_transfer_proposal<CoinType>(creator: &signer, aptocracy_account: address, treasury_address: address, name: String, description: String, 
    options: vector<String>, execution_hashes: vector<vector<vector<u8>>>, discussion_link: String, max_voter_options: u64,  transfer_address: address, transfer_amount: u64) {
    assert!(vector::length<String>(&options) == 1, EWRONG_OPTION_LENGHT);
    let option = *vector::borrow<String>(&options, 0);
    assert!(vector::length<vector<vector<u8>>>(&execution_hashes) == 1, EWRONG_OPTION_LENGHT);
    // let execution_step_hash = vector::borrow<vector<vector<u8>>>(&execution_hashes, 0);
    // assert!(vector::length<vector<u8>>(execution_step_hash) == 1, EWRONG_OPTION_LENGHT);

    let execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    vector::push_back(&mut execution_parameters, vector::empty<vector<vector<u8>>>());
    let option_execution_parameters = vector::borrow_mut<vector<vector<vector<u8>>>>(&mut execution_parameters, 0);
    vector::push_back<vector<vector<u8>>>(option_execution_parameters, vector::empty<vector<u8>>());
    let step_execution_parameters = vector::borrow_mut<vector<vector<u8>>>(option_execution_parameters, 0);
    
    let proposal_count: u64 = proposals::get_proposal_count<AptocracyProposal>(aptocracy_account) + 1;
    vector::push_back<vector<u8>>(step_execution_parameters, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&treasury_address));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&proposal_count));
    vector::push_back(step_execution_parameters, bcs::to_bytes<String>(&option));
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&transfer_address));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&transfer_amount));
    vector::push_back(step_execution_parameters, bcs::to_bytes<TypeInfo>(&type_info::type_of<CoinType>()));


    let execution_parameter_types = vector::empty<vector<vector<String>>>();
    vector::push_back(&mut execution_parameter_types, vector::empty<vector<String>>());
    let option_execution_parameter_types = vector::borrow_mut<vector<vector<String>>>(&mut execution_parameter_types, 0);
    vector::push_back<vector<String>>(option_execution_parameter_types, vector::empty<String>());
    let step_execution_parameter_types = vector::borrow_mut<vector<String>>(option_execution_parameter_types, 0);

    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"String"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"TypeInfo"));

    let treasury_metadata = treasury::get_treasury_metadata<AptocracyTreasury>(treasury_address);



    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      treasury_address,
      treasury_metadata.governance_id, 
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"Transfer")
    );
  }

  public entry fun execute_transfer_proposal<CoinType>(sender:&signer,aptocracy_account: address, treasury_address: address, proposal_id:u64, 
    option:String, transfer_address: address, transfer_amount: u64) {

    let args=vector::empty();
    vector::push_back(&mut args, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(&mut args, bcs::to_bytes<address>(&treasury_address));
    vector::push_back(&mut args, bcs::to_bytes<u64>(&proposal_id));
    vector::push_back(&mut args, bcs::to_bytes<String>(&option));
    vector::push_back(&mut args, bcs::to_bytes<address>(&transfer_address));
    vector::push_back(&mut args, bcs::to_bytes<u64>(&transfer_amount));
    vector::push_back(&mut args, bcs::to_bytes<TypeInfo>(&type_info::type_of<CoinType>()));

    execute_proposal(sender, proposal_id, args, option, aptocracy_account);
    treasury::transfer_funds<AptocracyTreasury, CoinType>(transfer_amount, transfer_address, treasury_address);


  }

  public entry fun create_withdrawal_proposal<CoinType>(creator: &signer, aptocracy_account: address, treasury_address: address, name: String, description: String, 
   options: vector<String>, execution_hashes: vector<vector<vector<u8>>>, discussion_link: String, max_voter_options: u64,  withdrawal_addresses: vector<address>, withdrawal_amount: u64) {
    assert!(vector::length<String>(&options) == 1, EWRONG_OPTION_LENGHT);
    let option = *vector::borrow<String>(&options, 0);
    assert!(vector::length<vector<vector<u8>>>(&execution_hashes) == 1, EWRONG_OPTION_LENGHT);
    // let execution_step_hash = vector::borrow<vector<vector<u8>>>(&execution_hashes, 0);
    // assert!(vector::length<vector<u8>>(execution_step_hash) == 1, EWRONG_OPTION_LENGHT);

    //check for withdrawal addresses
    //check number of members
    assert!(organization::get_number_of_members<AptocracyOrganization, AptocracyMember>(aptocracy_account) == vector::length<address>(&withdrawal_addresses), 0);
    //check if all addresses are unique and if is member
    let index = 0;
    let unique_withdrawal_addresses = vector::empty<address>();
    while(index < vector::length<address>(&withdrawal_addresses)) {
      let withdrawal_address = *vector::borrow<address>(&withdrawal_addresses, index);
      assert!(organization::is_member<AptocracyOrganization, AptocracyMember>(aptocracy_account, withdrawal_address), 0);
      assert!(!vector::contains<address>(&unique_withdrawal_addresses,&withdrawal_address), 0);
      vector::push_back<address>(&mut unique_withdrawal_addresses, withdrawal_address);
      index = index + 1;
    };


    let execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    vector::push_back(&mut execution_parameters, vector::empty<vector<vector<u8>>>());
    let option_execution_parameters = vector::borrow_mut<vector<vector<vector<u8>>>>(&mut execution_parameters, 0);
    vector::push_back<vector<vector<u8>>>(option_execution_parameters, vector::empty<vector<u8>>());
    let step_execution_parameters = vector::borrow_mut<vector<vector<u8>>>(option_execution_parameters, 0);
    
    let proposal_count: u64 = proposals::get_proposal_count<AptocracyProposal>(aptocracy_account) + 1;
    vector::push_back<vector<u8>>(step_execution_parameters, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&treasury_address));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&proposal_count));
    vector::push_back(step_execution_parameters, bcs::to_bytes<String>(&option));
    vector::push_back(step_execution_parameters, bcs::to_bytes<vector<address>>(&withdrawal_addresses));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&withdrawal_amount));
    vector::push_back(step_execution_parameters, bcs::to_bytes<TypeInfo>(&type_info::type_of<CoinType>()));


    let execution_parameter_types = vector::empty<vector<vector<String>>>();
    vector::push_back(&mut execution_parameter_types, vector::empty<vector<String>>());
    let option_execution_parameter_types = vector::borrow_mut<vector<vector<String>>>(&mut execution_parameter_types, 0);
    vector::push_back<vector<String>>(option_execution_parameter_types, vector::empty<String>());
    let step_execution_parameter_types = vector::borrow_mut<vector<String>>(option_execution_parameter_types, 0);

    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"String"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"vector<address>"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"TypeInfo"));


    let treasury_metadata = treasury::get_treasury_metadata<AptocracyTreasury>(treasury_address);

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      treasury_address,
      treasury_metadata.governance_id, 
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"Withdrawal")
    );
  }

  public entry fun execute_withdrawal_proposal<CoinType>(sender:&signer,aptocracy_account: address, treasury_address: address, proposal_id:u64, 
    option:String, withdrawal_addresses: vector<address>, withdrawal_amount: u64) {

    //checks
    //check number of members
    assert!(organization::get_number_of_members<AptocracyOrganization, AptocracyMember>(aptocracy_account) == vector::length<address>(&withdrawal_addresses), 0);
    //check if all addresses are unique and if is member
    let index = 0;
    let unique_withdrawal_addresses = vector::empty<address>();
    while(index < vector::length<address>(&withdrawal_addresses)) {
      let withdrawal_address = *vector::borrow<address>(&withdrawal_addresses, index);
      assert!(organization::is_member<AptocracyOrganization, AptocracyMember>(aptocracy_account, withdrawal_address), 0);
      assert!(!vector::contains<address>(&unique_withdrawal_addresses,&withdrawal_address), 0);
      vector::push_back<address>(&mut unique_withdrawal_addresses, withdrawal_address);
      index = index + 1;
    };
    
    let args=vector::empty();
    vector::push_back(&mut args, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(&mut args, bcs::to_bytes<address>(&treasury_address));
    vector::push_back(&mut args, bcs::to_bytes<u64>(&proposal_id));
    vector::push_back(&mut args, bcs::to_bytes<String>(&option));
    vector::push_back(&mut args, bcs::to_bytes<vector<address>>(&withdrawal_addresses));
    vector::push_back(&mut args, bcs::to_bytes<u64>(&withdrawal_amount));
    vector::push_back(&mut args, bcs::to_bytes<TypeInfo>(&type_info::type_of<CoinType>()));

    execute_proposal(sender, proposal_id, args, option, aptocracy_account);
    let total_deposited = treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address);
    let proposal_creation_time = proposals::get_proposal_creation_time<AptocracyProposal>(aptocracy_account, proposal_id);

    let index = 0;
    while(index < vector::length<address>(&withdrawal_addresses)) {
      let member_address = *vector::borrow<address>(&withdrawal_addresses, index);
      let member_deposited_amount = treasury::get_deposited_amount_for_address_for_timestamp<AptocracyTreasury>(treasury_address,member_address, proposal_creation_time);
      let member_withdrawal_amount = math64::mul_div((withdrawal_amount), member_deposited_amount, total_deposited);
      if(member_withdrawal_amount > 0) {
        treasury::transfer_funds<AptocracyTreasury, CoinType>(member_withdrawal_amount,member_address,treasury_address);
      };
      index = index + 1;
    }
  }

  public entry fun create_discussion_proposal(creator: &signer, aptocracy_account: address, treasury_address: address, name: String, description: String, options: vector<String>, discussion_link: String, max_voter_options: u64) {

    let execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    let execution_hashes = vector::empty<vector<vector<u8>>>();
    let execution_parameter_types = vector::empty<vector<vector<String>>>();
    let index = 0;
    while (index < vector::length<String>(&options)) {
      vector::push_back<vector<vector<vector<u8>>>>(&mut execution_parameters, vector::empty<vector<vector<u8>>>());
      vector::push_back<vector<vector<u8>>>(&mut execution_hashes, vector::empty<vector<u8>>());
      vector::push_back<vector<vector<String>>>(&mut execution_parameter_types, vector::empty<vector<String>>());
      index = index + 1;
    };

    let treasury_metadata = treasury::get_treasury_metadata<AptocracyTreasury>(treasury_address);

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      treasury_address, 
      treasury_metadata.governance_id,
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"Discussion")
    );

  }

  public entry fun change_governance_config_proposal(creator:&signer,name:String,description:String,
    governance_ids:vector<u64>,quorums:vector<u64>,approval_quorums:vector<u64>,
    max_voting_times:vector<u64>,early_tippings:vector<bool>, options:vector<String>,
    aptocracy_account:address,execution_hashes:vector<vector<vector<u8>>>,discussion_link:String,max_voter_options: u64){

    let creator_address=signer::address_of(creator);

    assert!(vector::length(&options)==vector::length(&governance_ids),EINVALID_CHANGE_GOVERNANCE_OPTIONS);

    organization::check_permission<AptocracyOrganization,AptocracyMember>(aptocracy_account,creator_address,CREATE_CHANGE_GOVERNANCE_CONFIG);

    let args_types=vector::empty<vector<vector<String>>>();
    let args=vector::empty<vector<vector<vector<u8>>>>();
    let governances_count=vector::length(&governance_ids);
    let index=0;

    while(index < governances_count){
      let serialized_args=vector::empty<vector<u8>>();
      let types=vector::empty<String>();
      let proposal_count: u64 = proposals::get_proposal_count<AptocracyProposal>(aptocracy_account) + 1;

      let governance=vector::borrow(&governance_ids,index);
      organization::check_if_governance_exist<AptocracyGovernance>(aptocracy_account, *governance);

      //check for quorum and approval values

      let quorum=vector::borrow(&quorums,index);
      let approval_quorum=vector::borrow(&approval_quorums,index);
      let max_voting_time=vector::borrow(&max_voting_times,index);
      let early_tipping=vector::borrow(&early_tippings,index);
      let option = vector::borrow<String>(&options, index);

      assert!(*quorum >= 0 && *quorum <= 100, EWRONG_QUORUM);
      assert!(*approval_quorum >= 0 && *approval_quorum <= 100, EWRONG_QUORUM);



      vector::push_back(&mut types,utf8(b"address"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(&aptocracy_account));

      vector::push_back(&mut types,utf8(b"u64"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(&proposal_count));

      vector::push_back(&mut types,utf8(b"u64"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(governance));

      vector::push_back(&mut types,utf8(b"String"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(option));

      vector::push_back(&mut types,utf8(b"u64"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(quorum));

      vector::push_back(&mut types,utf8(b"u64"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(approval_quorum));

      vector::push_back(&mut types,utf8(b"u64"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(max_voting_time));

      vector::push_back(&mut types,utf8(b"bool"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(early_tipping));

      vector::push_back(&mut types,utf8(b"address"));
      vector::push_back(&mut serialized_args,bcs::to_bytes(&creator_address));

      let option_args=vector::empty<vector<vector<u8>>>();
      vector::push_back(&mut option_args,serialized_args);

      let option_types=vector::empty();
      vector::push_back(&mut option_types,types);

      vector::push_back(&mut args,option_args);
      vector::push_back(&mut args_types,option_types);

      index=index+1;

    };

    let organization_metadata = organization::get_organization_metadata<AptocracyOrganization>(aptocracy_account);
    let main_governance = organization::get_main_governance<AptocracyOrganization>(aptocracy_account);
    
    //check for main governance and main treasury
    assert!(option::is_some<address>(&organization_metadata.main_treasury), EACCOUNT_NOT_EXIST);
    assert!(option::is_some<u64>(&main_governance), EACCOUNT_NOT_EXIST);

    let main_treasury: address =  *option::borrow<address>(&organization_metadata.main_treasury);
    let main_gov: u64 = *option::borrow<u64>(&main_governance);
    

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      main_treasury,
      main_gov,
      name, 
      description, 
      options,
      args, 
      args_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"ChangeGovernance")
    );
  } 

  public entry fun execute_change_config_proposal(sender:&signer,
    aptocracy_account:address,proposal_id:u64,governance_id:u64,
    option:String,new_quorum:u64,new_approval_quorum:u64,
    new_voting_time:u64,early_tipping:bool, creator: address){
    
    //checks
    check_if_proposal_treasury_and_gov_are_main(aptocracy_account, proposal_id);

    let serialized_args=vector::empty<vector<u8>>();

    vector::push_back(&mut serialized_args,bcs::to_bytes(&aptocracy_account));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&proposal_id));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&governance_id));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&option));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&new_quorum));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&new_approval_quorum));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&new_voting_time));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&early_tipping));
    vector::push_back(&mut serialized_args,bcs::to_bytes(&creator));

    execute_proposal(sender, proposal_id, serialized_args, option, aptocracy_account);

    organization::change_governance_config<AptocracyGovernance, AptocracyMember, AptocracyOrganization>(aptocracy_account,governance_id,new_quorum,new_voting_time
    ,early_tipping,new_approval_quorum, creator);

  }

  public entry fun create_update_main_governance_proposal(creator: &signer, aptocracy_account: address, name: String, description: String, 
   options: vector<String>, execution_hashes: vector<vector<vector<u8>>>, discussion_link: String, max_voter_options: u64, governance_id: u64) {
    assert!(vector::length<String>(&options) == 1, EWRONG_OPTION_LENGHT);

    assert!(vector::length<vector<vector<u8>>>(&execution_hashes) == 1, EWRONG_OPTION_LENGHT);
    organization::check_if_governance_exist<AptocracyGovernance>(aptocracy_account, governance_id);
   

    // let execution_step_hash = vector::borrow<vector<vector<u8>>>(&execution_hashes, 0);
    // assert!(vector::length<vector<u8>>(execution_step_hash) == 1, EWRONG_OPTION_LENGHT);

    let execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    vector::push_back(&mut execution_parameters, vector::empty<vector<vector<u8>>>());
    let option_execution_parameters = vector::borrow_mut<vector<vector<vector<u8>>>>(&mut execution_parameters, 0);
    vector::push_back<vector<vector<u8>>>(option_execution_parameters, vector::empty<vector<u8>>());
    let step_execution_parameters = vector::borrow_mut<vector<vector<u8>>>(option_execution_parameters, 0);
    

    let option = *vector::borrow<String>(&options, 0);
    let proposal_count: u64 = proposals::get_proposal_count<AptocracyProposal>(aptocracy_account) + 1;
    let creator_address: address = signer::address_of(creator);
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&proposal_count));
    vector::push_back(step_execution_parameters, bcs::to_bytes<String>(&option));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&governance_id));
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&creator_address));



    let execution_parameter_types = vector::empty<vector<vector<String>>>();
    vector::push_back(&mut execution_parameter_types, vector::empty<vector<String>>());
    let option_execution_parameter_types = vector::borrow_mut<vector<vector<String>>>(&mut execution_parameter_types, 0);
    vector::push_back<vector<String>>(option_execution_parameter_types, vector::empty<String>());
    let step_execution_parameter_types = vector::borrow_mut<vector<String>>(option_execution_parameter_types, 0);

    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"String"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));




    let organization_metadata = organization::get_organization_metadata<AptocracyOrganization>(aptocracy_account);
    let main_governance = organization::get_main_governance<AptocracyOrganization>(aptocracy_account);

    
    //check for main governance and main treasury
    assert!(option::is_some<address>(&organization_metadata.main_treasury), EACCOUNT_NOT_EXIST);
    assert!(option::is_some<u64>(&main_governance), EACCOUNT_NOT_EXIST);

    let main_treasury: address =  *option::borrow<address>(&organization_metadata.main_treasury);
    let main_gov: u64 = *option::borrow<u64>(&main_governance);

    

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      main_treasury,
      main_gov,
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"UpdateMainGovernance")
    );
  }

  public entry fun execute_update_main_governance_proposal(payer: &signer, aptocracy_account: address, proposal_id: u64,
   option: String, governance_id: u64, creator: address) {
      //checks
      check_if_proposal_treasury_and_gov_are_main(aptocracy_account, proposal_id);

      let args = vector::empty();
      vector::push_back(&mut args, bcs::to_bytes<address>(&aptocracy_account));
      vector::push_back(&mut args, bcs::to_bytes<u64>(&proposal_id));
      vector::push_back(&mut args, bcs::to_bytes<String>(&option));
      vector::push_back(&mut args, bcs::to_bytes<u64>(&governance_id));
      vector::push_back(&mut args, bcs::to_bytes<address>(&creator));


      execute_proposal(payer, proposal_id, args, option, aptocracy_account);
      organization::update_main_governance<AptocracyOrganization, AptocracyGovernance, AptocracyMember>(creator, aptocracy_account, governance_id);
  }

  public entry fun create_update_main_treasury_proposal(creator: &signer, aptocracy_account: address, name: String, description: String, 
   options: vector<String>, execution_hashes: vector<vector<vector<u8>>>, discussion_link: String, max_voter_options: u64, treasury_address: address) {
    assert!(vector::length<String>(&options) == 1, EWRONG_OPTION_LENGHT);

    assert!(vector::length<vector<vector<u8>>>(&execution_hashes) == 1, EWRONG_OPTION_LENGHT);
   
    assert!(treasury::check_if_treasury_exists<AptocracyTreasury>(treasury_address), EACCOUNT_NOT_EXIST);






    // let execution_step_hash = vector::borrow<vector<vector<u8>>>(&execution_hashes, 0);
    // assert!(vector::length<vector<u8>>(execution_step_hash) == 1, EWRONG_OPTION_LENGHT);

    let execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    vector::push_back(&mut execution_parameters, vector::empty<vector<vector<u8>>>());
    let option_execution_parameters = vector::borrow_mut<vector<vector<vector<u8>>>>(&mut execution_parameters, 0);
    vector::push_back<vector<vector<u8>>>(option_execution_parameters, vector::empty<vector<u8>>());
    let step_execution_parameters = vector::borrow_mut<vector<vector<u8>>>(option_execution_parameters, 0);

    let option = *vector::borrow<String>(&options, 0);
    let proposal_count: u64 = proposals::get_proposal_count<AptocracyProposal>(aptocracy_account) + 1;
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&aptocracy_account));
    vector::push_back(step_execution_parameters, bcs::to_bytes<u64>(&proposal_count));
    vector::push_back(step_execution_parameters, bcs::to_bytes<String>(&option));
    vector::push_back(step_execution_parameters, bcs::to_bytes<address>(&treasury_address));


    let execution_parameter_types = vector::empty<vector<vector<String>>>();
    vector::push_back(&mut execution_parameter_types, vector::empty<vector<String>>());
    let option_execution_parameter_types = vector::borrow_mut<vector<vector<String>>>(&mut execution_parameter_types, 0);
    vector::push_back<vector<String>>(option_execution_parameter_types, vector::empty<String>());
    let step_execution_parameter_types = vector::borrow_mut<vector<String>>(option_execution_parameter_types, 0);

    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"u64"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"String"));
    vector::push_back(step_execution_parameter_types, string::utf8(b"address"));

    let organization_metadata = organization::get_organization_metadata<AptocracyOrganization>(aptocracy_account);
    let main_governance = organization::get_main_governance<AptocracyOrganization>(aptocracy_account);

    
    //check for main governance and main treasury
    assert!(option::is_some<address>(&organization_metadata.main_treasury), EACCOUNT_NOT_EXIST);
    assert!(option::is_some<u64>(&main_governance), EACCOUNT_NOT_EXIST);



    let main_treasury: address =  *option::borrow<address>(&organization_metadata.main_treasury);
    let main_gov: u64 = *option::borrow<u64>(&main_governance);

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      main_treasury,
      main_gov,
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"UpdateMainTreasury")
    );
  }

  public entry fun execute_update_main_treasry_proposal(payer: &signer, aptocracy_account: address, proposal_id: u64,
   option: String, treasury_address: address) {
      //checks
      check_if_proposal_treasury_and_gov_are_main(aptocracy_account, proposal_id);
      
      let args = vector::empty();
      vector::push_back(&mut args, bcs::to_bytes<address>(&aptocracy_account));
      vector::push_back(&mut args, bcs::to_bytes<u64>(&proposal_id));
      vector::push_back(&mut args, bcs::to_bytes<String>(&option));
      vector::push_back(&mut args, bcs::to_bytes<address>(&treasury_address));
      execute_proposal(payer, proposal_id, args, option, aptocracy_account);
      let org_metadata = organization::get_organization_metadata<AptocracyOrganization>(aptocracy_account);
      let updated_org_metadata = org_metadata;
      updated_org_metadata.main_treasury = option::some<address>(treasury_address);
      organization::update_org_metadata<AptocracyOrganization>(aptocracy_account, updated_org_metadata);
  }

  public entry fun create_user_defined_proposal(creator: &signer, aptocracy_account: address, name: String, description: String, 
   options: vector<String>, execution_hashes: vector<vector<vector<u8>>>,execution_parameters:vector<vector<vector<vector<u8>>>>, execution_parameter_types:vector<vector<vector<String>>>, discussion_link: String, max_voter_options: u64, treasury_address: address) {
    assert!(vector::length<String>(&options) == 1, EWRONG_OPTION_LENGHT);

    assert!(vector::length<vector<vector<u8>>>(&execution_hashes) == 1, EWRONG_OPTION_LENGHT);
   

    // let execution_step_hash = vector::borrow<vector<vector<u8>>>(&execution_hashes, 0);
    // assert!(vector::length<vector<u8>>(execution_step_hash) == 1, EWRONG_OPTION_LENGHT);
    

   let treasury_metadata = treasury::get_treasury_metadata<AptocracyTreasury>(treasury_address);

    create_aptocracy_proposal(
      creator,
      aptocracy_account, 
      treasury_address,
      treasury_metadata.governance_id,
      name, 
      description, 
      options,
      execution_parameters, 
      execution_parameter_types, 
      execution_hashes, 
      discussion_link, 
      max_voter_options,
      string::utf8(b"Custom")
    );
  }

  public fun create_aptocracy_proposal(creator: &signer, aptocracy_account: address, treasury_address: address, governance_id: u64, name: String, description: String, options: vector<String>,execution_parameters:vector<vector<vector<vector<u8>>>>, execution_parameter_types:vector<vector<vector<String>>>, execution_hashes: vector<vector<vector<u8>>>, discussion_link: String, max_voter_options: u64, proposal_type: String) {
    assert!(exists<Aptocracy>(aptocracy_account), EACCOUNT_NOT_EXIST);
    organization::check_permission<AptocracyOrganization, AptocracyMember>(aptocracy_account, signer::address_of(creator), CREATE_PROPOSAL);
    let (max_voting_time, approval_quorum, quorum, early_tipping) = organization::get_governance_info<AptocracyOrganization, AptocracyGovernance>(aptocracy_account, governance_id);
    let org_type = organization::get_organization_type<AptocracyOrganization>(aptocracy_account);
    let max_voter_weight = organization::get_organization_max_voter_weight<AptocracyOrganization>(aptocracy_account);
    
    let proposal_max_voter_weight: u64;
    if(org_type == TOKEN_BASED) {
      proposal_max_voter_weight = treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address);
    } else {
      proposal_max_voter_weight = *option::borrow(&max_voter_weight);
    };

    proposals::create_proposal<AptocracyProposal>(
      signer::address_of(creator),
      aptocracy_account, 
      name,
      description,
      AptocracyProposal {
        discussion_link,
        treasury_address,
        aptocracy_address:aptocracy_account,
        proposal_type,
        number_of_votes: 0,
        governance_id
      },
      proposal_max_voter_weight,
      timestamp::now_seconds() + max_voting_time,
      approval_quorum,
      quorum,
      options,
      execution_parameters,
      execution_hashes,
      execution_parameter_types,
      max_voter_options,
      early_tipping
    )
  }

  fun check_if_proposal_treasury_and_gov_are_main(aptocracy_account: address, proposal_id: u64) {

    let organization_metadata = organization::get_organization_metadata<AptocracyOrganization>(aptocracy_account);
    let main_governance = organization::get_main_governance<AptocracyOrganization>(aptocracy_account);
    
    assert!(option::is_some<address>(&organization_metadata.main_treasury), EACCOUNT_NOT_EXIST);
    assert!(option::is_some<u64>(&main_governance), EACCOUNT_NOT_EXIST);

    let main_treasury: address =  *option::borrow<address>(&organization_metadata.main_treasury);
    let main_gov_id: u64 = *option::borrow<u64>(&main_governance);

    let proposal_metadata = proposals::get_proposal_metadata<AptocracyProposal>(aptocracy_account, proposal_id);
    assert!(proposal_metadata.treasury_address == main_treasury, EINVALID_TREASURY);
    assert!(proposal_metadata.governance_id == main_gov_id, EINVALID_GOVERNANCE);
  }

  #[test_only]
  public fun aidrop_coins(framework: &signer, destinations: vector<address>) {
    let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(framework);
    let index = 0;
    while(index < vector::length<address>(&destinations)) {
      let coin = coin::mint<AptosCoin>(100, &mint);
      let user_addr = *vector::borrow<address>(&destinations, index);
      coin::deposit(user_addr, coin);
      let balance = coin::balance<AptosCoin>(user_addr);
      assert!(balance == 100, 0);
      index = index + 1;
    };
    coin::destroy_burn_cap(burn);
    coin::destroy_mint_cap(mint);

  }

  #[test_only]
  public fun get_default_role_config(owner_weight: u64, member_weight: u64, manager_weight: u64): (vector<String>, vector<u64>, vector<vector<u64>>) {
    let role_names = vector::empty<String>();
    vector::push_back(&mut role_names, string::utf8(b"owner"));
    vector::push_back(&mut role_names, string::utf8(b"member"));
    vector::push_back(&mut role_names, string::utf8(b"manager"));

    let role_weights = vector::empty<u64>();
    vector::push_back(&mut role_weights,owner_weight);
    vector::push_back(&mut role_weights, member_weight);
    vector::push_back(&mut role_weights, manager_weight);

    let role_actions = vector::empty<vector<u64>>();
    let owner_actions = vector::empty<u64>();
    vector::push_back(&mut owner_actions, CHANGE_GOVERNANCE_CONFIG);
    vector::push_back(&mut owner_actions, CREATE_GOVERNANCE);
    vector::push_back(&mut owner_actions, INVITE_MEMBER);
    vector::push_back(&mut owner_actions, CREATE_TREASURY);
    vector::push_back(&mut owner_actions, SUPPORT_ORG);
    vector::push_back(&mut owner_actions, CAST_VOTE);
    vector::push_back(&mut owner_actions, CANCEL_PROPOSAL);
    vector::push_back(&mut owner_actions, FINALIZE_VOTES);
    vector::push_back(&mut owner_actions, RELINQUISH_VOTE);
    vector::push_back(&mut owner_actions, CREATE_PROPOSAL);
    vector::push_back(&mut owner_actions,UPDATE_MAIN_GOVERNANCE);
    vector::push_back(&mut owner_actions,UPDATE_MAIN_TREASURY);
    vector::push_back(&mut owner_actions,CREATE_CHANGE_GOVERNANCE_CONFIG);


    let manager_actions = vector::empty<u64>();
    vector::push_back(&mut manager_actions, INVITE_MEMBER);
    vector::push_back(&mut manager_actions, SUPPORT_ORG);
    vector::push_back(&mut manager_actions, CAST_VOTE);
    vector::push_back(&mut manager_actions, CANCEL_PROPOSAL);
    vector::push_back(&mut manager_actions, FINALIZE_VOTES);
    vector::push_back(&mut manager_actions, RELINQUISH_VOTE);
    vector::push_back(&mut owner_actions, CREATE_PROPOSAL);

    let member_actions = vector::empty<u64>();
    vector::push_back(&mut member_actions, SUPPORT_ORG);
    vector::push_back(&mut member_actions, CAST_VOTE);
    vector::push_back(&mut member_actions, CANCEL_PROPOSAL);
    vector::push_back(&mut member_actions, FINALIZE_VOTES);
    vector::push_back(&mut member_actions, RELINQUISH_VOTE);

    vector::push_back(&mut role_actions, owner_actions);
    vector::push_back(&mut role_actions, manager_actions);
    vector::push_back(&mut role_actions, member_actions);

    (
      role_names,
      role_weights,
      role_actions
    )
  }

  #[test_only]
  public fun test_aptocracy_create_deposit_based_org(account: &signer, invite_only: bool): address {
    let (role_names, role_weights, role_actions): (vector<String>, vector<u64>, vector<vector<u64>>) = get_default_role_config(0,0,0);
    create_organization<AptosCoin>(
      account, 
      string::utf8(b"Deposit based org"), 
      TOKEN_BASED,
      role_names,
      role_weights,
      role_actions,
      string::utf8(b"owner"),
      option::none(),
      option::none(),
      option::none(),
      invite_only,
      string::utf8(b"member")
    );

    let seeds: vector<u8> = bcs::to_bytes<String>(&string::utf8(b"Deposit based org"));
    let account_addr = account::create_resource_address(&signer::address_of(account), seeds);
    let (name, creator, org_type, org_metadata, max_voter_weight, governing_coin): (String, address, u64, AptocracyOrganization, Option<u64>, Option<TypeInfo>)
     = organization::get_organization_basic_data<AptocracyOrganization>(account_addr);
    assert!(name == string::utf8(b"Deposit based org"), 0);
    assert!(creator == signer::address_of(account), 0);
    assert!(org_type == TOKEN_BASED, 0);
    assert!(max_voter_weight == option::none(), 0);
    assert!(org_metadata.treasury_count == 0, 0);
    assert!(option::is_some<TypeInfo>(&governing_coin), 0);
    assert!(*option::borrow<TypeInfo>(&governing_coin) == type_info::type_of<AptosCoin>(), 0);
    account_addr
  }

  #[test_only]
  public fun test_aptocracy_create_role_based_org(account: &signer, invite_only: bool): address {
    let (role_names, role_weights, role_actions): (vector<String>, vector<u64>, vector<vector<u64>>) = get_default_role_config(20,10,15);
    create_organization<AptosCoin>(
      account, 
      string::utf8(b"Role based org"), 
      ROLE_BASED,
      role_names,
      role_weights,
      role_actions,
      string::utf8(b"owner"),
      option::none(),
      option::none(),
      option::none(),
      invite_only,
      string::utf8(b"member")
    );

    let seeds: vector<u8> = bcs::to_bytes<String>(&string::utf8(b"Role based org"));
    let account_addr = account::create_resource_address(&signer::address_of(account), seeds);
    let (name, creator, org_type, org_metadata, max_voter_weight, governing_coin): (String, address, u64, AptocracyOrganization, Option<u64>, Option<TypeInfo>)
     = organization::get_organization_basic_data<AptocracyOrganization>(account_addr);
    assert!(name == string::utf8(b"Role based org"),  0);
    assert!(creator == signer::address_of(account), 0);
    assert!(org_type == ROLE_BASED, 0);
    assert!(max_voter_weight == option::some(20), 0);
    assert!(org_metadata.treasury_count == 0, 0);
    assert!(option::is_some<TypeInfo>(&governing_coin), 0);
    assert!(*option::borrow<TypeInfo>(&governing_coin) == type_info::type_of<AptosCoin>(), 0);
    account_addr
  }

  #[test_only]
  public fun test_aptocracy_create_proposal(creator: &signer, aptocracy_account_addr: address, treasury_address: address, expected_max_voter_weight: u64, expected_max_voting_time: u64, expected_approval_quorum: u64, expected_quorum: u64, expected_early_tipping: bool) {
    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    let option_execution_parameters = vector::empty<vector<vector<vector<u8>>>>();
    let option_execution_hashes = vector::empty<vector<vector<u8>>>();
    let option_execution_parameter_types = vector::empty<vector<vector<String>>>();

    vector::push_back<vector<vector<vector<u8>>>>(&mut option_execution_parameters, vector::empty<vector<vector<u8>>>());
    vector::push_back<vector<vector<vector<u8>>>>(&mut option_execution_parameters, vector::empty<vector<vector<u8>>>());
    vector::push_back<vector<vector<u8>>>(&mut option_execution_hashes, vector::empty<vector<u8>>());
    vector::push_back<vector<vector<u8>>>(&mut option_execution_hashes, vector::empty<vector<u8>>());
    vector::push_back<vector<vector<String>>>(&mut option_execution_parameter_types, vector::empty<vector<String>>());
    vector::push_back<vector<vector<String>>>(&mut option_execution_parameter_types, vector::empty<vector<String>>());


    //Not for aptocracy proposals
    let treasury_metadata = treasury::get_treasury_metadata<AptocracyTreasury>(treasury_address);

    create_aptocracy_proposal(
      creator, 
      aptocracy_account_addr, 
      treasury_address, 
      treasury_metadata.governance_id,
      string::utf8(b"Test proposal"),
      string::utf8(b"Test proposal desc"),
      options,
      option_execution_parameters,
      option_execution_parameter_types,
      option_execution_hashes,
      string::utf8(b"link"),
      2,
      string::utf8(b"Test")
    );
    let (
      name, 
      description, 
      state, 
      proposal_creator, 
      proposal_content,
      max_vote_weight, 
      max_voting_time, 
      approval_quorum, 
      quorum, 
      max_voter_options, 
      created_at, 
      voting_finalized_at, 
      executed_at, 
      cancelled_at, 
      early_tipping) = proposals::get_proposal_info<AptocracyProposal>(aptocracy_account_addr, 1);

      assert!(name == string::utf8(b"Test proposal"), 0);
      assert!(description == string::utf8(b"Test proposal desc"), 0);
      assert!(state == 0, 0);
      assert!(proposal_creator == signer::address_of(creator), 0);
      assert!(proposal_content.discussion_link == string::utf8(b"link"), 0);
      assert!(proposal_content.treasury_address == treasury_address, 0);
      assert!(max_vote_weight == expected_max_voter_weight, 0);
      assert!(max_voting_time == timestamp::now_seconds() + expected_max_voting_time, 0);
      assert!(approval_quorum == expected_approval_quorum, 0);
      assert!(quorum == expected_quorum, 0);
      assert!(max_voter_options == 2, 0);
      assert!(created_at == timestamp::now_seconds(), 0);
      assert!(voting_finalized_at == option::none<u64>(), 0);
      assert!(executed_at == option::none<u64>(), 0);
      assert!(cancelled_at == option::none<u64>(), 0);
      assert!(early_tipping == expected_early_tipping, 0);
  }

  #[test_only]
  public fun test_aptocracy_create_governance(creator: &signer, aptocracy_account_addr: address, max_voting_time: u64, approval_quorum: u64, quorum: u64, early_tipping: bool, governance_id: u64) {
    create_governance(creator, aptocracy_account_addr, max_voting_time, approval_quorum, quorum, early_tipping);
    let (updated_max_voting_time, updated_approval_quorum, updated_quorum, updated_early_tipping): (u64, u64, u64, bool) = organization::get_governance_info<AptocracyOrganization, AptocracyGovernance>(aptocracy_account_addr, governance_id);
    assert!(max_voting_time == updated_max_voting_time, 0);
    assert!(approval_quorum == updated_approval_quorum, 0);
    assert!(quorum == updated_quorum, 0);
    assert!(early_tipping == updated_early_tipping, 0);
  }

  #[test_only]
  public fun test_aptocracy_create_treasury(creator: &signer, aptocracy_account_addr: address, governance_id: u64, treasury_count: u32) : (address) acquires Aptocracy {
    create_treasury<AptosCoin>(creator, aptocracy_account_addr, governance_id);
    let seeds = bcs::to_bytes(&string::utf8(b"treasury"));
    vector::append(&mut seeds, bcs::to_bytes<u32>(&(treasury_count))); 
    let treasury_address = account::create_resource_address(&aptocracy_account_addr, seeds);
    let (authority, treasury_index, treasury_coin, deposited_amount): (address, u32, TypeInfo, u64) = treasury::get_basic_treasury_info<AptocracyTreasury>(treasury_address);
    assert!(authority == aptocracy_account_addr, 0);
    assert!(treasury_index == 1, 0);
    assert!(treasury_coin == type_info::type_of<AptosCoin>(), 0);
    assert!(deposited_amount == 0, 0);
    treasury_address
  }

  #[test(framework = @0x1, creator = @0x123, member = @0x323, manager = @0x554)]
  public fun test_aptocracy_deposit_org_flow(framework: signer, creator: signer, member: signer, manager: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    let manager_addr = signer::address_of(&manager);
    aptos_framework::aptos_account::create_account(copy manager_addr);

    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);


    invite_aptocracy_member(&creator, aptocracy_account_addr, member_addr, string::utf8(b"member"));
    let (role, status, member_metadata): (String, u8, AptocracyMember) = organization::get_member_info<AptocracyOrganization, AptocracyMember>(aptocracy_account_addr, member_addr);
    assert!(role ==  string::utf8(b"member"), 0);
    assert!(status == 0, 0);
    assert!(member_metadata.proposal_created == 0, 0);

    invite_aptocracy_member(&creator, aptocracy_account_addr, manager_addr, string::utf8(b"manager"));
    let (manager_role, manager_status, manager_member_metadata): (String, u8, AptocracyMember) = organization::get_member_info<AptocracyOrganization, AptocracyMember>(aptocracy_account_addr, manager_addr);
    assert!(manager_role ==  string::utf8(b"manager"), 0);
    assert!(manager_status == 0, 0);
    assert!(manager_member_metadata.proposal_created == 0, 0);

    accept_aptocracy_membership(&member, aptocracy_account_addr);
    let (_role, status, _member_metadata): (String, u8, AptocracyMember) = organization::get_member_info<AptocracyOrganization, AptocracyMember>(aptocracy_account_addr, member_addr);
    assert!(status == 1, 0);

    accept_aptocracy_membership(&manager, aptocracy_account_addr);
    let (_role, status, _member_metadata): (String, u8, AptocracyMember) = organization::get_member_info<AptocracyOrganization, AptocracyMember>(aptocracy_account_addr, manager_addr);
    assert!(status == 1, 0);
    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    vector::push_back<address>(&mut aidrop_addresses_vec, manager_addr);


    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, member_addr) == 10, 0);
    support_org<AptosCoin>(&manager, aptocracy_account_addr, 5, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, manager_addr) == 5, 0);
    assert!(treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address) == 15, 0);

    test_aptocracy_create_proposal(&creator, aptocracy_account_addr, treasury_address, 15, 120, 30, 41, true);
    timestamp::fast_forward_seconds(2);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    cast_vote(&member, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), options);

    let (_options, vote_weight) = proposals::get_user_vote_info<AptocracyProposal>(aptocracy_account_addr, 1, member_addr);
    assert!(vote_weight == 10, 0);

    let (state) = proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1);
    assert!(state == 1, 0);
  }

  #[test(framework = @0x1, creator = @0x123, member = @0x323, manager = @0x554)]
  public fun test_aptocracy_role_based_org_flow(framework: signer, creator: signer, member: signer, manager: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    let manager_addr = signer::address_of(&manager);
    aptos_framework::aptos_account::create_account(copy manager_addr);

    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_role_based_org(&creator, true);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 0, 70, 51, false, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);


    invite_aptocracy_member(&creator, aptocracy_account_addr, member_addr, string::utf8(b"member"));
    invite_aptocracy_member(&creator, aptocracy_account_addr, manager_addr, string::utf8(b"manager"));
    accept_aptocracy_membership(&member, aptocracy_account_addr);
    accept_aptocracy_membership(&manager, aptocracy_account_addr);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    vector::push_back<address>(&mut aidrop_addresses_vec, manager_addr);


    test_aptocracy_create_proposal(&creator, aptocracy_account_addr, treasury_address, 45, 0, 70, 51, false);

    let member_options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut member_options, string::utf8(b"Option1"));

    let creator_options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut creator_options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut creator_options, string::utf8(b"Option2"));

    let manager_options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut manager_options, string::utf8(b"Option2"));


    cast_vote(&creator, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), creator_options);
    cast_vote(&manager, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), manager_options);
    cast_vote(&member, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), member_options);
    

    let (state) = proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1);
    assert!(state == 0, 0);
    finalize_votes_for_aptocracy_proposal(&creator, aptocracy_account_addr, 1);
    let (updated_state) = proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1);
    assert!(updated_state == 1, 0);

    assert!(!proposals::is_option_elected<AptocracyProposal>(aptocracy_account_addr, 1, string::utf8(b"Option1")), 0);
    assert!(proposals::is_option_elected<AptocracyProposal>(aptocracy_account_addr, 1, string::utf8(b"Option2")), 0);



  }

  #[test(framework = @0x1, creator = @0x123, member = @0x432)]
  public fun test_support_without_invite(framework: signer, creator: signer, member: signer) acquires Aptocracy{
     //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);
  }

  #[test(framework = @0x1, creator = @0x123, member = @0x432)]
  public fun test_cancel_and_relinquish_proposal(framework: signer, creator: signer, member: signer) acquires Aptocracy{
     //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, false, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);

    test_aptocracy_create_proposal(&creator, aptocracy_account_addr, treasury_address, 10, 120, 30, 41, false);

    let member_options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut member_options, string::utf8(b"Option1"));

    cast_vote(&member, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), member_options);
    assert!(proposals::does_user_vote_on_proposal<AptocracyProposal>(aptocracy_account_addr, 1, member_addr), 0);
    relinquish_vote(&member, aptocracy_account_addr, 1);
    assert!(!proposals::does_user_vote_on_proposal<AptocracyProposal>(aptocracy_account_addr, 1, member_addr), 0);

    cancel_aptocracy_proposal(&member, aptocracy_account_addr, 1);
    let (state) = proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1);
    assert!(state == 4, 0);

    
  }

  #[test(framework = @0x1, creator = @0x123)]
  #[expected_failure]
  public fun test_aptocracy_create_treasury_without_governance(framework: signer, creator: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);

    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    let _treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);

  }

  #[test(framework = @0x1, creator = @0x123, member = @0x432)]
  #[expected_failure]
  public fun test_support_invite_only_org(framework: signer, creator: signer, member: signer) acquires Aptocracy{
     //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, true);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);
  }
  
  #[test(framework = @0x1, creator = @0x123, member = @0x432)]
  #[expected_failure]
  public fun test_missing_action(framework: signer, creator: signer, member: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, true);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    test_aptocracy_create_treasury(&member, aptocracy_account_addr, 1, 1);
  }


 #[test(framework = @0x1, creator = @0x123, member = @0x323, manager = @0x554)]
   public fun test_transfer_funds_proposal(framework: signer, creator: signer, member: signer, manager: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    let manager_addr = signer::address_of(&manager);
    aptos_framework::aptos_account::create_account(copy manager_addr);

    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);


    invite_aptocracy_member(&creator, aptocracy_account_addr, member_addr, string::utf8(b"member"));
    invite_aptocracy_member(&creator, aptocracy_account_addr, manager_addr, string::utf8(b"manager"));
    accept_aptocracy_membership(&member, aptocracy_account_addr);
    accept_aptocracy_membership(&manager, aptocracy_account_addr);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    vector::push_back<address>(&mut aidrop_addresses_vec, manager_addr);
    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, member_addr) == 10, 0);
    support_org<AptosCoin>(&manager, aptocracy_account_addr, 5, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, manager_addr) == 5, 0);
    assert!(treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address) == 15, 0);
    assert!(coin::balance<AptosCoin>(member_addr) == 90, 0);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Transfer"));

    let execution_hashes = vector::empty<vector<vector<u8>>>();
    let test_execution_hash = transaction_context::get_script_hash();
    let option_execution_hashes = vector::empty<vector<u8>>();
    vector::push_back(&mut option_execution_hashes, test_execution_hash);
    vector::push_back<vector<vector<u8>>>(&mut execution_hashes, option_execution_hashes);

    create_transfer_proposal<AptosCoin>(&creator, aptocracy_account_addr, treasury_address, string::utf8(b"Test name"),  string::utf8(b"Test desc"),
    options, execution_hashes,  string::utf8(b"Test link"), 1, member_addr, 5);
    cast_vote(&member, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), options);
    execute_transfer_proposal<AptosCoin>(&creator, aptocracy_account_addr, treasury_address, 1, string::utf8(b"Transfer"), member_addr, 5);
    assert!(treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address) == 15, 0);
    assert!(coin::balance<AptosCoin>(treasury_address) == 10, 0);
    assert!(coin::balance<AptosCoin>(member_addr) == 95, 0);
  }

  #[test(framework = @0x1, creator = @0x123, member = @0x323, manager = @0x554)]
  public fun test_withdraw_funds_proposal(framework: signer, creator: signer, member: signer, manager: signer) acquires Aptocracy {
    //Prepare accounts for test
    let creator_addr = signer::address_of(&creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    let member_addr = signer::address_of(&member);
    aptos_framework::aptos_account::create_account(copy member_addr);
    let manager_addr = signer::address_of(&manager);
    aptos_framework::aptos_account::create_account(copy manager_addr);

    timestamp::set_time_has_started_for_testing(&framework);

    let aptocracy_account_addr = test_aptocracy_create_deposit_based_org(&creator, false);
    test_aptocracy_create_governance(&creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(&creator, aptocracy_account_addr, 1, 1);


    invite_aptocracy_member(&creator, aptocracy_account_addr, member_addr, string::utf8(b"member"));
    invite_aptocracy_member(&creator, aptocracy_account_addr, manager_addr, string::utf8(b"manager"));
    accept_aptocracy_membership(&member, aptocracy_account_addr);
    accept_aptocracy_membership(&manager, aptocracy_account_addr);

    let aidrop_addresses_vec = vector::empty<address>();
    vector::push_back<address>(&mut aidrop_addresses_vec, member_addr);
    vector::push_back<address>(&mut aidrop_addresses_vec, manager_addr);
    aidrop_coins(&framework, aidrop_addresses_vec);
    support_org<AptosCoin>(&member, aptocracy_account_addr, 10, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, member_addr) == 10, 0);
    support_org<AptosCoin>(&manager, aptocracy_account_addr, 5, treasury_address);
    assert!(treasury::get_deposited_amount_for_address<AptocracyTreasury>(treasury_address, manager_addr) == 5, 0);
    assert!(treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address) == 15, 0);
    assert!(coin::balance<AptosCoin>(member_addr) == 90, 0);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Withdrawal"));
    let execution_hashes = vector::empty<vector<vector<u8>>>();
    let test_execution_hash = transaction_context::get_script_hash();
    let option_execution_hashes = vector::empty<vector<u8>>();
    vector::push_back(&mut option_execution_hashes, test_execution_hash);
    vector::push_back<vector<vector<u8>>>(&mut execution_hashes, option_execution_hashes);

    //Add all members to vector
    let withdrawal_addresses = vector::empty<address>();
    vector::push_back<address>(&mut withdrawal_addresses, member_addr);
    vector::push_back<address>(&mut withdrawal_addresses, manager_addr);
    vector::push_back<address>(&mut withdrawal_addresses, creator_addr);


    create_withdrawal_proposal<AptosCoin>(&creator, aptocracy_account_addr, treasury_address, string::utf8(b"Test name"),  string::utf8(b"Test desc"),
    options, execution_hashes,  string::utf8(b"Test link"), 1, withdrawal_addresses, 5);
    cast_vote(&member, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), options);
    execute_withdrawal_proposal<AptosCoin>(&creator, aptocracy_account_addr, treasury_address, 1, string::utf8(b"Withdrawal"), withdrawal_addresses, 5);
    assert!(treasury::get_accumulated_treasury_amount<AptocracyTreasury>(treasury_address) == 15, 0);

    assert!(coin::balance<AptosCoin>(manager_addr) == 96, 0);
    assert!(coin::balance<AptosCoin>(member_addr) == 93, 0);
    assert!(coin::balance<AptosCoin>(treasury_address) == 11, 0);

    assert!(proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1) == 3, 0);
  }

  #[test(framework = @0x1, creator = @0x123)]
  public fun test_create_discussion_proposal(framework: signer, creator: &signer): (address, address) acquires Aptocracy {
    let creator_addr = signer::address_of(creator);
    aptos_framework::aptos_account::create_account(copy creator_addr);
    timestamp::set_time_has_started_for_testing(&framework);
    
    let aptocracy_account_addr = test_aptocracy_create_role_based_org(creator, false);
    test_aptocracy_create_governance(creator, aptocracy_account_addr, 120, 30, 41, true, 1);
    let treasury_address = test_aptocracy_create_treasury(creator, aptocracy_account_addr, 1, 1);
    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Test 1"));
    vector::push_back<String>(&mut options, string::utf8(b"Test 2"));

    create_discussion_proposal(creator, aptocracy_account_addr, treasury_address, string::utf8(b"Test name"),  string::utf8(b"Test desc"), options, string::utf8(b"Test link"), 2);
    cast_vote(creator, aptocracy_account_addr, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), options);
    assert!(proposals::get_proposal_state<AptocracyProposal>(aptocracy_account_addr, 1) == 1, 0);
    (aptocracy_account_addr, treasury_address)
  }

 #[test(framework = @0x1, creator = @0x123)]
  #[expected_failure]
  public fun test_execute_discussion_proposal(framework: signer, creator: signer) acquires Aptocracy {
    let (aptocracy_account_addr, _treasury_address) = test_create_discussion_proposal(framework,&creator);
    execute_proposal(&creator, 1, vector::empty(),string::utf8(b"Test 1"), aptocracy_account_addr);
  }
  
  #[test(framework = @0x1, creator = @0x123, member = @0x323, manager = @0x554)]
  fun test_create_update_governance_config(framework:&signer,creator:&signer):address acquires Aptocracy{
    use std::transaction_context;
    timestamp::set_time_has_started_for_testing(framework);
    let organization_address=test_aptocracy_create_role_based_org(creator,true);
    test_aptocracy_create_governance(creator,organization_address,120, 30, 41,true,1);
    update_main_org_governance(creator,organization_address,1);
    test_aptocracy_create_governance(creator,organization_address,100, 60, 81,true,2);
    let main_governance=organization::get_main_governance<AptocracyOrganization>(organization_address);
    assert!(option::is_some(&main_governance),2);
    let governance_ids=vector::empty<u64>();
    let quorums=vector::empty<u64>();
    let voting_times=vector::empty<u64>();
    let early_tippings=vector::empty<bool>();
    let approval_quorums=vector::empty<u64>();
    vector::push_back(&mut governance_ids,1);
    vector::push_back(&mut quorums,45);
    vector::push_back(&mut voting_times,181);
    vector::push_back(&mut early_tippings,true);
    vector::push_back(&mut approval_quorums,30);
    let treasury_address=test_aptocracy_create_treasury(creator,organization_address,2,1);
    update_main_org_treasury(creator, organization_address, treasury_address);
    let org_metadata = organization::get_organization_metadata<AptocracyOrganization>(organization_address);
    assert!(option::is_some<address>(&org_metadata.main_treasury), 0);

    let execution_hashes=vector::empty();

    let exec_hash=vector::empty();
    vector::push_back(&mut exec_hash,transaction_context::get_script_hash());

    vector::push_back(&mut execution_hashes,exec_hash);
  

    let options=vector::empty<String>();
    vector::push_back(&mut options,utf8(b"Change main governance"));

    change_governance_config_proposal(creator,utf8(b"Change gov config"),
    utf8(b"Changing two governances config"),governance_ids,quorums,approval_quorums,voting_times,early_tippings,
    options,organization_address,execution_hashes,utf8(b"Some discussion link"), 1);

    let (_name,
      _description,
      _state,
      _creator,
      _proposal_content,
      _max_vote_weight,
      _max_voting_time,
       approval_quorum,
       quorum,
      _max_voter_options,
      _created_at,
      _voting_finalized_at,
      _executed_at,
      _cancelled_at,
      _early_tipping)=proposals::get_proposal_info<AptocracyProposal>(organization_address,1);

      assert!(approval_quorum==30,2);
      assert!(quorum==41,3);

      let options=vector::empty();
      vector::push_back(&mut options,utf8(b"Change main governance"));
      cast_vote(creator, organization_address, treasury_address, 1, vector::empty<String>(), vector::empty<u64>(), options);
      (organization_address,1,utf8(b"Change main governance"));

      organization_address
  }


  #[test(framework=@0x1,creator=@0x2,member=@0x3,manager=@0x4)]
  fun test_execute_change_governance_config(framework:&signer,creator:&signer) acquires Aptocracy{
    let organization_address=test_create_update_governance_config(framework,creator);
    execute_change_config_proposal(creator,organization_address,1,1,utf8(b"Change main governance"),
      45, 30 ,181,true, signer::address_of(creator));
      let (max_voting_time,approval_quorum,quorum,early_tipping)=
      organization::get_governance_info<AptocracyOrganization,AptocracyGovernance>(organization_address,1);
      assert!(early_tipping,4);
      assert!(max_voting_time==181,6);
      assert!(approval_quorum==30,7);
      assert!(quorum==45,8);  
  }

  #[test(framework=@0x1,creator=@0x2)]
  #[expected_failure(abort_code=13,location=proposals)]
  fun test_fail_execute_change_gov_config(framework:&signer,creator:&signer) acquires Aptocracy{
      let organization_address=test_create_update_governance_config(framework,creator);
      execute_change_config_proposal(creator,organization_address,1,1,utf8(b"Change main governance"),
       49,30,181,true, signer::address_of(creator));
  }


}

