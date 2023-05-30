
module org_lib_addr::organization {
  use std::string::{String};
  use std::simple_map::{Self, SimpleMap};
  use std::table_with_length::{Self, TableWithLength};
  use std::vector;
  use std::signer;
  use std::option::{Self, Option};
  use std::type_info::{Self, TypeInfo};
  use aptos_token::token;
  use aptos_framework::account;
  use std::event::{Self,EventHandle};
  #[test_only]
  use aptos_framework::aptos_coin::AptosCoin;
  #[test_only]
  use std::string;


  struct Organization<OrganizationMetadata: store + copy + drop> has key {
    creator: address,
    name: String,
    role_config: SimpleMap<String, RoleConfig>,
    org_type: u64,
    organization_metadata: OrganizationMetadata,
    max_voter_weight: Option<u64>, //Total nfts in NFT orgs or sum of role_weight in ROLE BASED
    governing_collection_info: Option<GoverningCollectionInfo>, //For NFT orgs
    governing_coin: Option<TypeInfo>, //For deposit based orgs,
    invite_only: bool,
    default_role: String,
    main_governance: Option<u64>
  }



  struct GoverningCollectionInfo has store, drop, copy {
    name: String,
    creator: address
  }

  struct RoleConfig has store, drop, copy {
    role_weight: u64,
    org_actions: vector<u64>,
  }

  struct Members<MemberMetadata: store> has key {
    members: TableWithLength<address, Member<MemberMetadata>>,
  }

  struct Member<MemberMetadata: store> has store {
    role: String,
    status: u8,
    member_metadata: MemberMetadata
  }

  struct Governances<GovernanceMetadata: store> has key {
    governances: SimpleMap<u64, Governance<GovernanceMetadata>>
  }
  struct Governance<GovernanceMetadata> has store {
    max_voting_time: u64,
    approval_quorum: u64,
    quorum: u64,
    early_tipping: bool,
    governance_metadata: GovernanceMetadata
  }

  struct OrganizationEvents has key {
    accept_membership: EventHandle<AcceptMembershipEvent>,
  }

  struct AcceptMembershipEvent has store, drop {
    member_address: address,
    organization_address: address,
    member_status: u8,
    role: String
  }


  //Member status
  const PENDING: u8 = 0;
  const ACCEPTED: u8 = 1;
  const REJECTED: u8 = 2;
  const CANCELED: u8 = 3;



  //Org types
  const ROLE_BASED: u64 = 0;
  const TOKEN_BASED: u64 = 1;
  const NFT_BASED: u64 = 2;

  //Actions
  const CHANGE_GOVERNANCE_CONFIG:u64 =0;
  const CREATE_GOVERNANCE:u64 =1;
  const INVITE_MEMBER:u64 = 2;
  const UPDATE_MAIN_GOVERNANCE:u64 = 3;

  //ERRORS
  ///Organization type does not exist
  const EWRONG_ORG_TYPE: u64 = 14;
  ///Invalid permission
  const EINVALID_PERMISSION: u64 = 15;
  ///Member already exist
  const EMEMBER_ALREADY_EXIST: u64 = 16;
  ///Role does not exist
  const EWRONG_ROLE: u64 = 17;
  ///Member record does not exist
  const EMEMBER_DOES_NOT_EXSIT: u64 = 18;
  ///Wrong member status
  const EWRONG_MEMBER_STATUS: u64 = 19;
  ///Wrong governance
  const EWRONG_GOVERNANCE: u64 = 20;
  ///Wrong organization address
  const EWRONG_ORG: u64 = 21;
  ///Resource doesnt exist
  const ERESOURCE_DOESNT_EXIST: u64 = 22;
  ///Collection doesnt exist
  const ECOLLECTION_DOESNT_EXIST: u64 = 23;
  ///Missing nft info
  const EMISSING_TOKEN_INFO: u64 = 24;
  ///Governing collection not defined
  const EGOVERNING_COLLECTION_NOT_DEFINED: u64 = 25;
  ///Organization is invite only
  const EINVITE_ONLY: u64 = 25;
  ///Quorum must be between 0 and 100
  const EINVALID_QUORUM_VALUE: u64 = 26;



  public fun create_organization<OrganizationMetadata: store + copy + drop, GovernanceMetadata: store, MemberMetadata: store, GoverningCoinType>(account: &signer, creator: address , name: String,  org_type: u64, role_names:vector<String>, 
    role_weights: vector<u64>, role_actions: vector<vector<u64>>,  owner_role: String, total_nft_votes: Option<u64>, creator_address: Option<address>, collection_name: Option<String>, org_metadata: OrganizationMetadata, member_metadata: MemberMetadata, invite_only: bool, default_role: String) {

    assert!(org_type == ROLE_BASED || org_type == TOKEN_BASED || org_type == NFT_BASED, EWRONG_ORG_TYPE);

    let initial_members:  TableWithLength<address, Member<MemberMetadata>> = table_with_length::new<address, Member<MemberMetadata>>();
    table_with_length::add<address, Member<MemberMetadata>>(&mut initial_members, creator , Member<MemberMetadata> {
        role: owner_role,
        status: ACCEPTED,
        member_metadata
    });

    let role_config = simple_map::create<String, RoleConfig>();

    let index = 0;
    while(index < vector::length<String>(&role_names)) {
      let role_name = vector::borrow<String>(&role_names, index);
      let role_weight = vector::borrow<u64>(&role_weights, index);
      let role_actions = vector::borrow<vector<u64>>(&role_actions, index);
      simple_map::add<String, RoleConfig>(&mut role_config, *role_name, RoleConfig {
        role_weight: *role_weight,
        org_actions: *role_actions
      });
      index=index + 1;
    };

    let owner_role_config = simple_map::borrow<String, RoleConfig>(&role_config, &owner_role);


    let governing_collection_info;
    if(org_type == NFT_BASED) {
      let collection_name = *option::borrow<String>(&collection_name);
      let creator = *option::borrow<address>(&creator_address);
      assert!(token::check_collection_exists(creator,collection_name),ECOLLECTION_DOESNT_EXIST);
      governing_collection_info = option::some(GoverningCollectionInfo {
        name: collection_name,
        creator
      });

    } else {
      governing_collection_info = option::none();
    };

    move_to(
      account,
      Organization<OrganizationMetadata> {
        name,
        org_type: org_type,
        role_config: copy role_config,
        creator,
        max_voter_weight: calculate_max_voter_weight(org_type, total_nft_votes, owner_role_config.role_weight),
        organization_metadata: org_metadata, 
        governing_collection_info,
        governing_coin: option::some(type_info::type_of<GoverningCoinType>()),
        invite_only,
        default_role,
        main_governance: option::none()

      }
    );

    move_to(
      account,
      Governances<GovernanceMetadata> {
        governances: simple_map::create<u64, Governance<GovernanceMetadata>>()
      }
    );

    move_to(
      account,
      Members<MemberMetadata> {
        members: initial_members
      }
    );

    move_to(
      account,
      OrganizationEvents {
        accept_membership: account::new_event_handle<AcceptMembershipEvent>(account)
      }
    )

  }

  public fun create_governance<OrganizationMetadata: store + copy + drop, MemberMetadata: store, GovernanceMetadata: store>(creator: &signer, organization_address: address, max_voting_time: u64, approval_quorum: u64, quorum: u64, early_tipping: bool, governance_metadata: GovernanceMetadata)  acquires Governances, Members, Organization {
    let organization = borrow_global_mut<Organization<OrganizationMetadata>>(organization_address);
    let creator_address = signer::address_of(creator);

    assert!(exists<Members<MemberMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    //Add check for custom error
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,creator_address);
    let member_role_config = simple_map::borrow<String, RoleConfig>(&organization.role_config, &member_data.role);

    //check if user has role to create proposal
    assert!(vector::contains<u64>(&member_role_config.org_actions, &CREATE_GOVERNANCE), EINVALID_PERMISSION);
    assert!(exists<Governances<GovernanceMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let governances = borrow_global_mut<Governances<GovernanceMetadata>>(organization_address);
    let next_gov_index = simple_map::length<u64, Governance<GovernanceMetadata>>(&governances.governances) + 1;

    //check quorum and approval quorum values
    assert!(quorum >= 0 && quorum <= 100, EINVALID_QUORUM_VALUE);
    assert!(approval_quorum >= 0 && approval_quorum <= 100, EINVALID_QUORUM_VALUE);

    simple_map::add<u64, Governance<GovernanceMetadata>>(&mut governances.governances,next_gov_index, Governance<GovernanceMetadata> {
      max_voting_time,
      approval_quorum,
      quorum,
      early_tipping,
      governance_metadata
    });
  }

  public fun invite_member<OrganizationMetadata: store + copy + drop, MemberMetadata: store>(payer: &signer, organization_address: address, 
    member_address: address, role: String, member_metadata: MemberMetadata) acquires Organization, Members {
    let organization = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    
    //Check is payer member of org and has permission to create invitation
    assert!(exists<Members<MemberMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let members = borrow_global_mut<Members<MemberMetadata>>(organization_address);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,signer::address_of(payer));
    let member_role_config = simple_map::borrow<String, RoleConfig>(&organization.role_config, &member_data.role);
    assert!(vector::contains<u64>(&member_role_config.org_actions, &INVITE_MEMBER), EINVALID_PERMISSION);
    assert!(member_data.status == ACCEPTED, EINVALID_PERMISSION);

    //Check if member is not already member of the org
    assert!(!table_with_length::contains<address, Member<MemberMetadata>>(&members.members, member_address),EMEMBER_ALREADY_EXIST);
    //Check if role exist in role config
    assert!(simple_map::contains_key<String, RoleConfig>(&organization.role_config, &role), EWRONG_ROLE);


    table_with_length::add<address, Member<MemberMetadata>>(&mut members.members, member_address, Member<MemberMetadata> {
        role,
        status: PENDING,
        member_metadata
    });

  }
  
  public fun accept_membership<OrganizationMetadata:store + copy + drop, MemberMetadata: store>(payer: &signer, organization_address: address) acquires Organization, Members, OrganizationEvents {
    let organization = borrow_global_mut<Organization<OrganizationMetadata>>(organization_address);
    let member_address = signer::address_of(payer);
    let members = borrow_global_mut<Members<MemberMetadata>>(organization_address);
    assert!(table_with_length::contains<address, Member<MemberMetadata>>(&members.members,member_address), EMEMBER_DOES_NOT_EXSIT);
    let member_data = table_with_length::borrow_mut<address, Member<MemberMetadata>>(&mut members.members,member_address);
    assert!(member_data.status == PENDING, EWRONG_MEMBER_STATUS);
    member_data.status = ACCEPTED;
    if(organization.org_type == ROLE_BASED) {
      let role_config = simple_map::borrow_mut<String, RoleConfig>(&mut organization.role_config, &member_data.role);
      organization.max_voter_weight = option::some<u64>(*option::borrow(&organization.max_voter_weight) + role_config.role_weight);
    };

    let organization_events = borrow_global_mut<OrganizationEvents>(organization_address);
    event::emit_event<AcceptMembershipEvent>(
      &mut organization_events.accept_membership,
      AcceptMembershipEvent {
        member_address,
        organization_address,
        member_status: ACCEPTED,
        role: member_data.role
      }
    )
  }

  public fun update_main_governance<OrganizationMetadata: store + copy + drop, GovernanceMetadata: store, MemberMetadata: store>(member_address:address, organization_address: address, governance_id: u64) acquires Organization, Governances, Members {
    let organization = borrow_global_mut<Organization<OrganizationMetadata>>(organization_address);
    let governances = borrow_global<Governances<GovernanceMetadata>>(organization_address);
    assert!(simple_map::contains_key<u64, Governance<GovernanceMetadata>>(&governances.governances, &governance_id), EWRONG_GOVERNANCE);
    //check if user has permission to update main governance
    assert!(exists<Members<MemberMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let members = borrow_global_mut<Members<MemberMetadata>>(organization_address);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,member_address);
    let member_role_config = simple_map::borrow<String, RoleConfig>(&organization.role_config, &member_data.role);
    assert!(vector::contains<u64>(&member_role_config.org_actions, &UPDATE_MAIN_GOVERNANCE), EINVALID_PERMISSION);

    organization.main_governance = option::some<u64>(governance_id);
  }

  public fun change_governance_config<GovernanceMetadata:store+copy+drop, MemberMetadata: store, OrganizationMetadata: store + copy + drop> (organization_address:address,governance_id:u64,new_quorum:u64,
    new_voting_time:u64,early_tipping:bool,new_approval_quorum:u64, member_address: address) acquires Governances, Members, Organization {

    let organization = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    assert!(exists<Members<MemberMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let members = borrow_global_mut<Members<MemberMetadata>>(organization_address);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,member_address);
    let member_role_config = simple_map::borrow<String, RoleConfig>(&organization.role_config, &member_data.role);
    assert!(vector::contains<u64>(&member_role_config.org_actions, &CHANGE_GOVERNANCE_CONFIG), EINVALID_PERMISSION);

    assert!(new_quorum >= 0 && new_quorum <= 100, EINVALID_QUORUM_VALUE);
    assert!(new_approval_quorum >= 0 && new_approval_quorum <= 100, EINVALID_QUORUM_VALUE);

    let governances=borrow_global_mut<Governances<GovernanceMetadata>>(organization_address);
    let governance=simple_map::borrow_mut<u64,Governance<GovernanceMetadata>>(&mut governances.governances,&governance_id);
      governance.quorum=new_quorum;
      governance.approval_quorum=new_approval_quorum;
      governance.early_tipping=early_tipping;
      governance.max_voting_time=new_voting_time;
  }


  public fun join_organization<OrganizationMetadata: store + copy + drop, MemberMetadata: store>(payer: &signer, organization_address: address, member_metadata: MemberMetadata) acquires Organization, Members {
    let organization = borrow_global_mut<Organization<OrganizationMetadata>>(organization_address);
    assert!(!organization.invite_only, EINVITE_ONLY);

    let member_address = signer::address_of(payer);
    let members = borrow_global_mut<Members<MemberMetadata>>(organization_address);
    assert!(!table_with_length::contains<address, Member<MemberMetadata>>(&members.members, member_address),EMEMBER_ALREADY_EXIST);
    table_with_length::add<address, Member<MemberMetadata>>(&mut members.members, member_address, Member<MemberMetadata> {
        role: organization.default_role,
        status: ACCEPTED,
        member_metadata
    });
    if(organization.org_type == ROLE_BASED) {
      let role_config = simple_map::borrow_mut<String, RoleConfig>(&mut organization.role_config, &organization.default_role);
      organization.max_voter_weight = option::some<u64>(*option::borrow(&organization.max_voter_weight) + role_config.role_weight);
    }

  }

  #[view]
  public fun get_main_governance<OrganizationMetadata:store+drop+copy>(aptocracy_account:address):Option<u64> acquires Organization{

    let organization=borrow_global<Organization<OrganizationMetadata>>(aptocracy_account);

    organization.main_governance
  }


  public fun check_permission<OrganizationMetadata:store + copy + drop, MemberMetadata: store>(organization_address: address, member_address: address, action: u64) acquires Organization, Members {
    let organization = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    assert!(table_with_length::contains<address, Member<MemberMetadata>>(&members.members,member_address), EMEMBER_DOES_NOT_EXSIT);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,member_address);
    assert!(member_data.status == ACCEPTED, EWRONG_MEMBER_STATUS);
    let member_role_config = simple_map::borrow<String, RoleConfig>(&organization.role_config, &member_data.role);
    assert!(vector::contains<u64>(&member_role_config.org_actions, &action), EINVALID_PERMISSION);
  }

  public fun check_if_governance_exist<GovernanceMetadata: store>(organization_address: address, governance_id: u64) acquires Governances {
    let governances = borrow_global_mut<Governances<GovernanceMetadata>>(organization_address);
    assert!(simple_map::contains_key<u64, Governance<GovernanceMetadata>>(&governances.governances, &governance_id), EWRONG_GOVERNANCE);
  }

  public fun update_org_metadata<OrganizationMetadata: store + copy + drop>(organization_address: address, organization_metadata: OrganizationMetadata) acquires Organization {
    assert!(exists<Organization<OrganizationMetadata>>(organization_address), ERESOURCE_DOESNT_EXIST);
    let organization = borrow_global_mut<Organization<OrganizationMetadata>>(organization_address);
    organization.organization_metadata = organization_metadata;
  }

  fun calculate_max_voter_weight(org_type: u64, total_nft_votes: Option<u64>, owner_role_weight: u64): Option<u64> {
    if(org_type == TOKEN_BASED) {
      return option::none()
    };
    if(org_type == NFT_BASED) {
      assert!(option::is_some<u64>(&total_nft_votes), 0);
      return total_nft_votes
    };
    if(org_type == ROLE_BASED) {
      return option::some(owner_role_weight)

    };
    abort EWRONG_ORG_TYPE
  }

  fun check_token_info_for_nft_orgs(org_gov_collection_info: Option<GoverningCollectionInfo>,creator_token_property_version: Option<u64>, creator_token_name: Option<String>, holder_address: address) {
    assert!(option::is_some<u64>(&creator_token_property_version), EMISSING_TOKEN_INFO);
    assert!(option::is_some<String>(&creator_token_name), EMISSING_TOKEN_INFO);
    let property_version = *option::borrow<u64>(&creator_token_property_version);
    let token_name = *option::borrow<String>(&creator_token_name);
    let governing_collection_info = *option::borrow<GoverningCollectionInfo>(&org_gov_collection_info);
    let token_id = token::create_token_id_raw(governing_collection_info.creator, governing_collection_info.name,token_name, property_version);
    assert!(token::balance_of(holder_address, token_id) > 0, EMISSING_TOKEN_INFO);
  }

  public fun get_organization_basic_data<OrganizationMetadata: store + copy + drop>(organization_address: address): (String, address, u64, OrganizationMetadata, Option<u64>, Option<TypeInfo>) acquires Organization {
    let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    (
      org.name,
      org.creator,
      org.org_type,
      org.organization_metadata,
      org.max_voter_weight,
      org.governing_coin
    )
  }

  public fun get_governance_info<OrganizationMetadata: store + copy + drop, GovernanceMetadata: store>(organization_address: address, governance_id: u64): (u64, u64, u64, bool) acquires  Governances {
    assert!(exists<Organization<OrganizationMetadata>>(organization_address),EWRONG_ORG);
    let governances = borrow_global<Governances<GovernanceMetadata>>(organization_address);
    assert!(simple_map::contains_key<u64, Governance<GovernanceMetadata>>(&governances.governances, &governance_id), EWRONG_GOVERNANCE);
    let governance = simple_map::borrow<u64, Governance<GovernanceMetadata>>(&governances.governances, &governance_id);
    (
      governance.max_voting_time,
      governance.approval_quorum,
      governance.quorum,
      governance.early_tipping
    )
  }


  public fun get_organization_metadata<OrganizationMetadata: store + copy + drop>(organization_address: address):(OrganizationMetadata) acquires Organization{
     let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
     (
      org.organization_metadata
     )
  }

  public fun get_organization_type<OrganizationMetadata: store + copy + drop>(organization_address: address): (u64) acquires Organization {
    let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
     (
      org.org_type
     )
  }

  public fun get_organization_max_voter_weight<OrganizationMetadata: store + copy + drop>(organization_address: address): (Option<u64>) acquires Organization {
     let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
     (
      org.max_voter_weight
     )
  }

  public fun get_governing_collection_info<OrganizationMetadata: store + copy + drop>(organization_address: address): (String, address) acquires Organization {
    let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    assert!(option::is_some<GoverningCollectionInfo>(&org.governing_collection_info), EGOVERNING_COLLECTION_NOT_DEFINED);
    let collection_info = *option::borrow<GoverningCollectionInfo>(&org.governing_collection_info);
    (
      collection_info.name,
      collection_info.creator
    )
  }

  public fun get_member_role_info<OrganizationMetadata: store + copy + drop, MemberMetadata: store>(organization_address: address, member_address: address): (u64, vector<u64>) acquires Organization, Members{
    let org = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,member_address);
    let role_info = simple_map::borrow<String, RoleConfig>(&org.role_config, &member_data.role);
    (
      role_info.role_weight,
      role_info.org_actions
    )
  }

  public fun get_member_info<OrganizationMetadata: store + copy + drop, MemberMetadata: store + copy + drop>(organization_address: address, member_address:address): (String, u8, MemberMetadata) acquires Members {
    assert!(exists<Organization<OrganizationMetadata>>(organization_address),EWRONG_ORG);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    let member_data = table_with_length::borrow<address, Member<MemberMetadata>>(&members.members,member_address);
    (
      member_data.role,
      member_data.status,
      member_data.member_metadata
    )

  }

  public fun get_number_of_members<OrganizationMetadata: store + copy + drop, MemberMetadata: store + copy + drop>(organization_address: address): (u64) acquires Members {
    assert!(exists<Organization<OrganizationMetadata>>(organization_address),EWRONG_ORG);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    (
      table_with_length::length<address, Member<MemberMetadata>>(&members.members)
    )

  }

  public fun is_invite_only<OrganizationMetadata: store + copy + drop>(organization_address: address): (bool) acquires Organization {
    let organization = borrow_global<Organization<OrganizationMetadata>>(organization_address);
    (
      organization.invite_only
    )
  }

  public fun is_member<OrganizationMetadata: store + copy + drop, MemberMetadata: store + copy + drop>(organization_address: address, member_address: address): (bool) acquires Members {
    assert!(exists<Organization<OrganizationMetadata>>(organization_address),EWRONG_ORG);
    let members = borrow_global<Members<MemberMetadata>>(organization_address);
    (
      table_with_length::contains<address, Member<MemberMetadata>>(&members.members, member_address)
    )
  }


  #[test_only]
  struct TestOrganizationMetadata has store, copy, drop {
    counter: u64
  }

  #[test_only]
  struct TestMemberMetadata has store, copy,drop {
    name: String
  }

    #[test_only]
  struct DifferentTestMemberMetadata has store, copy,drop {
    name: String
  }


  #[test_only]
  struct TestGovernanceMetadata has store, copy,drop {
    name: String
  }

  #[test_only]
  struct DifferentGovernanceMetadata has store, copy,drop {
    name: String
  }


  #[test_only]
  public fun test_create_deposit_based_organization(account: &signer, creator: &signer, name: String) {
    //Setup roles
    let role_names = vector::empty<String>();
    vector::push_back(&mut role_names, string::utf8(b"owner"));
    vector::push_back(&mut role_names, string::utf8(b"member"));
    vector::push_back(&mut role_names, string::utf8(b"manager"));

    let role_weights = vector::empty<u64>();
    vector::push_back(&mut role_weights,0);
    vector::push_back(&mut role_weights, 0);
    vector::push_back(&mut role_weights, 0);

    let role_actions = vector::empty<vector<u64>>();
    let owner_actions = vector::empty<u64>();
    vector::push_back(&mut owner_actions, 1);
    vector::push_back(&mut owner_actions, 2);
    let manager_actions = vector::empty<u64>();
    vector::push_back(&mut manager_actions, 2);
    let member_actions = vector::empty<u64>();
    vector::push_back(&mut role_actions, owner_actions);
    vector::push_back(&mut role_actions, manager_actions);
    vector::push_back(&mut role_actions, member_actions);

    create_organization<TestOrganizationMetadata, TestGovernanceMetadata, TestMemberMetadata, AptosCoin>(
      account,
      signer::address_of(creator),
      name,
      TOKEN_BASED,
      role_names,
      role_weights,
      role_actions,
      string::utf8(b"owner"),
      option::none<u64>(),
      option::none<address>(),
      option::none<String>(),
      TestOrganizationMetadata {
        counter: 0
      },
      TestMemberMetadata {
        name: string::utf8(b"Test")
      },
      false,
      string::utf8(b"member")
    );
  }

  #[test_only]
  public fun test_create_role_based_organization(account: &signer, creator: &signer, name: String) {
    //Setup roles
    let role_names = vector::empty<String>();
    vector::push_back(&mut role_names, string::utf8(b"owner"));
    vector::push_back(&mut role_names, string::utf8(b"member"));
    vector::push_back(&mut role_names, string::utf8(b"manager"));

    let role_weights = vector::empty<u64>();
    vector::push_back(&mut role_weights, 10);
    vector::push_back(&mut role_weights, 20);
    vector::push_back(&mut role_weights, 30);

    let role_actions = vector::empty<vector<u64>>();
    let owner_actions = vector::empty<u64>();
    vector::push_back(&mut owner_actions, 1);
    vector::push_back(&mut owner_actions, 2);
    let manager_actions = vector::empty<u64>();
    vector::push_back(&mut manager_actions, 2);
    let member_actions = vector::empty<u64>();
    vector::push_back(&mut role_actions, owner_actions);
    vector::push_back(&mut role_actions, manager_actions);
    vector::push_back(&mut role_actions, member_actions);

    create_organization<TestOrganizationMetadata, TestGovernanceMetadata, TestMemberMetadata, AptosCoin>(
      account,
      signer::address_of(creator),
      name,
      ROLE_BASED,
      role_names,
      role_weights,
      role_actions,
      string::utf8(b"owner"),
      option::none<u64>(),
      option::none<address>(),
      option::none<String>(),
      TestOrganizationMetadata {
        counter: 0
      },
      TestMemberMetadata {
        name: string::utf8(b"Test")
      },
      false,
      string::utf8(b"member")
    );
  }



  #[test_only]
  public fun test_nft_based_organization(account: &signer, creator: &signer, name: String) {
    //Setup roles
    let role_names = vector::empty<String>();
    vector::push_back(&mut role_names, string::utf8(b"owner"));
    vector::push_back(&mut role_names, string::utf8(b"member"));
    vector::push_back(&mut role_names, string::utf8(b"manager"));

    let role_weights = vector::empty<u64>();
    vector::push_back(&mut role_weights, 0);
    vector::push_back(&mut role_weights, 0);
    vector::push_back(&mut role_weights, 0);

    let role_actions = vector::empty<vector<u64>>();
    let owner_actions = vector::empty<u64>();
    vector::push_back(&mut owner_actions, 1);
    vector::push_back(&mut owner_actions, 2);
    let manager_actions = vector::empty<u64>();
    vector::push_back(&mut manager_actions, 2);
    let member_actions = vector::empty<u64>();
    vector::push_back(&mut role_actions, owner_actions);
    vector::push_back(&mut role_actions, manager_actions);
    vector::push_back(&mut role_actions, member_actions);


    token::create_collection_and_token(
      creator,
      1,
      2,
      1,
      vector<String>[],
      vector<vector<u8>>[],
      vector<String>[],
      vector<bool>[false, false, false],
      vector<bool>[false, false, false, false, false],
    );

    create_organization<TestOrganizationMetadata, TestGovernanceMetadata, TestMemberMetadata, AptosCoin>(
      account,
      signer::address_of(creator),
      name,
      NFT_BASED,
      role_names,
      role_weights,
      role_actions,
      string::utf8(b"owner"),
      option::some<u64>(10),
      option::some<address>(signer::address_of(creator)),
      option::some<String>(string::utf8(b"Hello, World")),
      TestOrganizationMetadata {
        counter: 0
      },
      TestMemberMetadata {
        name: string::utf8(b"Test")
      },
      false,
      string::utf8(b"member")
    );
  }


  #[test(account = @0x333, creator = @0x123, member = @0x321, manager = @0x323)]
  public fun test_org_flow(account: signer, creator: signer, member: signer, manager: signer) acquires Organization, Members, Governances,OrganizationEvents{
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let account_addr = signer::address_of(&account);
    account::create_account_for_test(signer::address_of(&account));
    let member_addr = signer::address_of(&member);
    let manager_addr = signer::address_of(&manager);

    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org"));
    create_governance<TestOrganizationMetadata, TestMemberMetadata, TestGovernanceMetadata>(&creator, account_addr, 5 * 60, 40, 51, true, TestGovernanceMetadata {
      name: string::utf8(b"Test governance")
    });
    invite_member<TestOrganizationMetadata, TestMemberMetadata>(&creator, account_addr, member_addr, string::utf8(b"member"), TestMemberMetadata {
      name: string::utf8(b"Test member")
    });
    let members = borrow_global<Members<TestMemberMetadata>>(account_addr);
    let invited_member = table_with_length::borrow<address, Member<TestMemberMetadata>>(&members.members, member_addr);
    assert!(invited_member.role ==  string::utf8(b"member"), 0);
    assert!(invited_member.status ==  PENDING, 0);
    assert!(invited_member.member_metadata.name == string::utf8(b"Test member"), 0);

    accept_membership<TestOrganizationMetadata, TestMemberMetadata>(&member,account_addr);
    let updated_members = borrow_global<Members<TestMemberMetadata>>(account_addr);
    let accepted_member = table_with_length::borrow<address, Member<TestMemberMetadata>>(&updated_members.members, member_addr);
    assert!(accepted_member.status == ACCEPTED, 0);

    invite_member<TestOrganizationMetadata, TestMemberMetadata>(&creator, account_addr, manager_addr, string::utf8(b"manager"), TestMemberMetadata {
      name: string::utf8(b"Test manager")
    });
    accept_membership<TestOrganizationMetadata, TestMemberMetadata>(&manager,account_addr);
  }

  #[test(account = @0x333, creator = @0x123)]
  #[expected_failure(abort_code = EMEMBER_ALREADY_EXIST)]
  public fun test_invite_member_that_already_exists(account: signer, creator: signer) acquires Organization, Members, Governances{
    //Prepare accounts for test
    let account_addr = signer::address_of(&account);
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));

    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org"));
    create_governance<TestOrganizationMetadata, TestMemberMetadata, TestGovernanceMetadata>(&creator, account_addr, 5 * 60, 40, 51, true, TestGovernanceMetadata {
      name: string::utf8(b"Test governance")
    });
    invite_member<TestOrganizationMetadata, TestMemberMetadata>(&creator, account_addr,  signer::address_of(&creator), string::utf8(b"member"), TestMemberMetadata {
      name: string::utf8(b"Test member")
    });
  }

  #[test(account = @0x333, creator = @0x123)]
  #[expected_failure(abort_code = EWRONG_MEMBER_STATUS)]
  public fun test_duplicate_accept_membership(account: signer, creator: signer) acquires Organization, Members, Governances,OrganizationEvents{
    //Prepare accounts for test
    let account_addr = signer::address_of(&account);
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));

    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org"));
    create_governance<TestOrganizationMetadata, TestMemberMetadata, TestGovernanceMetadata>(&creator, account_addr, 5 * 60, 40, 51, true, TestGovernanceMetadata {
      name: string::utf8(b"Test governance")
    });
    accept_membership<TestOrganizationMetadata, TestMemberMetadata>(&creator,account_addr);
  }

  #[test(account = @0x333, creator = @0x123)]
  #[expected_failure(abort_code = EINVALID_PERMISSION)]
  public fun test_check_if_role_action_exist(account: signer, creator: signer) acquires Organization, Members {
    //Prepare accounts for test
    let account_addr = signer::address_of(&account);
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));


    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org"));
    check_permission<TestOrganizationMetadata, TestMemberMetadata>(account_addr, signer::address_of(&creator), 1);
    check_permission<TestOrganizationMetadata, TestMemberMetadata>(account_addr, signer::address_of(&creator), 10);
  }

  #[test(account = @0x333, creator = @0x123)]
  #[expected_failure(abort_code = ERESOURCE_DOESNT_EXIST)]
  public fun test_wrong_governance_metadata(account: signer, creator: signer) acquires Organization, Governances, Members {
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));
    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org 2"));
    create_governance<TestOrganizationMetadata, TestMemberMetadata, DifferentGovernanceMetadata>(&creator, signer::address_of(&account), 5 * 60, 40, 51, true, DifferentGovernanceMetadata {
      name: string::utf8(b"Test governance")
    });
  }

  #[test(account = @0x333, creator = @0x123, member = @0x321)]
  #[expected_failure(abort_code = ERESOURCE_DOESNT_EXIST)]
  public fun test_wrong_member_metadata(account: signer, creator: signer, member: signer) acquires Organization, Members {
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));
    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org 2"));
     invite_member<TestOrganizationMetadata, DifferentTestMemberMetadata>(&creator, signer::address_of(&account),  signer::address_of(&member), string::utf8(b"member"), DifferentTestMemberMetadata {
      name: string::utf8(b"Test member")
    });
  }

  #[test(account = @0x333, creator = @0x123)]
  public fun test_update_org_metadata(account: signer, creator: signer) acquires Organization {
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));
    test_create_deposit_based_organization(&account, &creator, string::utf8(b"Deposit based org 2"));
    let account_addr = signer::address_of(&account);
    let org_metadata = get_organization_metadata<TestOrganizationMetadata>(account_addr);
    update_org_metadata<TestOrganizationMetadata>(account_addr, TestOrganizationMetadata {
      counter: org_metadata.counter + 1
    });
    let updated_org_metadata = get_organization_metadata<TestOrganizationMetadata>(account_addr);
    assert!(updated_org_metadata.counter == 1, 0);
  }
  
  #[test(account = @0x333, creator = @0x123)]
  public fun test_role_based_max_voter_weight(account: signer, creator: signer) acquires Organization {
    account::create_account_for_test(signer::address_of(&creator));
    account::create_account_for_test(signer::address_of(&account));
    test_create_role_based_organization(&account, &creator, string::utf8(b"Role based test"));
    let organization = borrow_global<Organization<TestOrganizationMetadata>>(signer::address_of(&account));
    assert!(option::is_some(&organization.max_voter_weight), 0);
    assert!(*option::borrow(&organization.max_voter_weight) == 10, 0);
  }

}