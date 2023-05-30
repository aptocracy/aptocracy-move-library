module org_lib_addr::proposals {
  use std::table_with_length::{Self, TableWithLength};
  use std::option::{Self, Option};
  use std::string::{String};
  use std::signer;
  use std::vector;
  use std::account;
  use std::event::{Self,EventHandle};
  use std::transaction_context;
  use aptos_framework::timestamp;
  #[test_only]
  use std::string;

  struct Proposals<ProposalMetadata: store> has key {
    proposals: TableWithLength<u64, Proposal<ProposalMetadata>>
  }


  struct Proposal<ProposalMetadata: store> has store {
    name: String,
    description: String,
    state: u8,
    creator: address,
    max_vote_weight: u64,
    max_voting_time: u64,
    vote_threshold: VoteThreshold,
    vote_options: TableWithLength<String, VoteOption>,
    proposal_content: ProposalMetadata,
    max_voter_options: u64,
    created_at: u64,
    voting_finalized_at: Option<u64>,
    executed_at: Option<u64>,
    cancelled_at: Option<u64>,
    early_tipping: bool,
  }

  struct ExecutionStep has store,copy,drop {
    execution_hash: vector<u8>,
    execution_parameters: vector<vector<u8>>,
    execution_parameter_types: vector<String>,
    executed: bool
  }

  struct VoteOption has store,copy,drop {
    vote_weight: u64,
    execution_steps: vector<ExecutionStep>,
    option_elected: bool
  }

  struct VoteThreshold has store {
    approval_quorum: u64,
    quorum: u64
  }

  struct VotingRecords has key {
    votes: TableWithLength<VoteKey,Vote>,
    accumulated_votes_weight: u64
  }

  struct VoteKey has copy, drop, store {
    proposal_id: u64,
    member_address: address
  }
  
  struct Vote has store, drop, copy {
    options: vector<String>,
    vote_weight: u64
  }

   struct VoteEvent<ProposalMetadata:store+drop> has store,drop{
    proposal_id:u64,
    proposal_content:ProposalMetadata,
    proposal_state:u8,
    vote_options:vector<String>,
    options_elected:vector<bool>,
    voting_finalized_at:Option<u64>,
    member_address:address,
    vote_weight:u64
  }

  struct RelinquishVoteEvent<ProposalMetadata> has store,drop{
    member_address:address,
    vote_weight:u64,
    vote_options:vector<String>,
    proposal_id:u64,
    proposal_content:ProposalMetadata,
    options_elected:vector<bool>,
  }

  struct FinalizeVoteEvent<ProposalMetadata> has store,drop{
    proposal_id:u64,
    proposal_content:ProposalMetadata,
    proposal_state:u8,
    voting_finalized_at:u64,
  }

  struct CancelProposalEvent<ProposalMetadata> has store,drop{
    proposal_state:u8,
    proposal_id:u64,
    proposal_content:ProposalMetadata,
    cancelled_at:u64
  }

  struct ExecuteProposalOptionEvent<ProposalMetadata> has store,drop{
    option:String,
    proposal_id:u64,
    proposal_content:ProposalMetadata,
    proposal_state:u8
  }

  struct ProposalEvents<ProposalMetadata:store+drop> has key{
    vote_event:EventHandle<VoteEvent<ProposalMetadata>>,
    relinquish_vote:EventHandle<RelinquishVoteEvent<ProposalMetadata>>,
    finalize_vote:EventHandle<FinalizeVoteEvent<ProposalMetadata>>,
    cancel_event:EventHandle<CancelProposalEvent<ProposalMetadata>>,
    execute_option:EventHandle<ExecuteProposalOptionEvent<ProposalMetadata>>
  }

  const STATE_VOTING: u8 = 0;
  const STATE_SUCCEEDED: u8 = 1;
  const STATE_EXECUTING: u8 = 2;
  const STATE_COMPLETED: u8 = 3;
  const STATE_CANCELLED: u8 = 4;
  const STATE_DEFEATED: u8 = 5; 

  //ERRORS
  ///Proposals resource already exist
  const EPROPOSALS_RESOURCE_ALREADY_EXISTS: u64 = 0;
  ///Wrong quorum value
  const EWRONG_QUORUM_VALUE: u64 = 1;
  ///Options array can not be empty
  const EEMPTY_OPTIONS: u64 = 2;
  ///Options must have be unique
  const EDUPLICATE_OPTION: u64 = 3;
  ///Proposal does not exist
  const EPROPOSAL_DOESNT_EXIST: u64 = 4;
  ///Proposal is in the wrong state 
  const EWRONG_PROPOSAL_STATE: u64 = 5;
  ///User already voted 
  const EALREADY_VOTED: u64 = 6;
  ///Option is not defined
  const EWRONG_OPTION: u64 = 7;
  ///Voting is still in progress
  const EVOTING_IN_PROGRESS: u64 = 8;
  ///Can not vote after voting time has passed
  const EVOTING_TIME_PASSED: u64 = 9;
  ///Vote doesnot exist
  const EVOTE_DOESNT_EXIST: u64 = 10;
  ///Option not elected
  const EOPTION_NOT_ELECTED:u64=11;
  ///Invalid proposal hash
  const EINVALID_HASH:u64=12;
  ///Invalid script paramteres
  const EINVALID_SCRIPT_PARAMS:u64=13;
  ///Can't execute proposal without script hash
  const ENON_EXECUTABLE_PROPOSAL:u64=14;
  ///Can not vote for more option then maximum
  const EWRONG_OPTIONS_LEN:u64=15;


  public fun initialize<ProposalMetadata: store+drop>(account: &signer) {
    let account_address = signer::address_of(account);
    assert!(!exists<Proposals<ProposalMetadata>>(account_address), EPROPOSALS_RESOURCE_ALREADY_EXISTS);
      move_to(
      account,
      VotingRecords {
        votes: table_with_length::new<VoteKey, Vote>(),
        accumulated_votes_weight: 0
      }
    );
    move_to(
      account,
      Proposals {
        proposals: table_with_length::new<u64, Proposal<ProposalMetadata>>()
      }
    );

    move_to(account,ProposalEvents<ProposalMetadata>{
      vote_event:account::new_event_handle<VoteEvent<ProposalMetadata>>(account),
      relinquish_vote:account::new_event_handle<RelinquishVoteEvent<ProposalMetadata>>(account),
      finalize_vote:account::new_event_handle<FinalizeVoteEvent<ProposalMetadata>>(account),
      cancel_event:account::new_event_handle<CancelProposalEvent<ProposalMetadata>>(account),
      execute_option:account::new_event_handle<ExecuteProposalOptionEvent<ProposalMetadata>>(account)
    })
  }

  public fun create_proposal<ProposalMetadata: store>(creator: address, 
    authority_account: address, name: String, description: String, 
    proposal_content: ProposalMetadata,
    max_vote_weight: u64, max_voting_time: u64, approval_quorum: u64, 
    quorum: u64, options: vector<String>, 
    execution_parameters: vector<vector<vector<vector<u8>>>>, 
    execution_hashes: vector<vector<vector<u8>>>, execution_parameter_types: vector<vector<vector<String>>>,max_voter_options: u64, early_tipping: bool
    ) acquires Proposals {
      //CHECKS:
      //options can not be empty
      assert!(vector::length<String>(&options) > 0, EEMPTY_OPTIONS);
      //approval_quorum must be between 0 and 100
      assert!(approval_quorum >= 0, EWRONG_QUORUM_VALUE);
      assert!(approval_quorum <= 100, EWRONG_QUORUM_VALUE);
      //quorum must be between 0 and 100
      assert!(quorum >= 0, EWRONG_QUORUM_VALUE);
      assert!(quorum <= 100, EWRONG_QUORUM_VALUE);

      //option must have unique names
      let option_names = vector::empty<String>();
      let index = 0;
      while(index < vector::length<String>(&options)){
        let option = *vector::borrow<String>(&options, index);
        assert!(!vector::contains<String>(&option_names, &option), EDUPLICATE_OPTION);
        vector::push_back<String>(&mut option_names, option);
        index = index+1;
      };

      let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
      let proposals_count = table_with_length::length(&proposals.proposals);

      let vote_options: TableWithLength<String, VoteOption> = table_with_length::new<String, VoteOption>();
      let vote_options_index = 0;
      while(vote_options_index < vector::length<String>(&options)) {
        let option = *vector::borrow<String>(&options, vote_options_index);
        let option_execution_parameters = *vector::borrow<vector<vector<vector<u8>>>>(&execution_parameters, vote_options_index);
        let option_execution_hashes = *vector::borrow<vector<vector<u8>>>(&execution_hashes, vote_options_index);
        let option_execution_parameter_types = *vector::borrow<vector<vector<String>>>(&execution_parameter_types, vote_options_index);

        let execution_steps: vector<ExecutionStep> = vector::empty<ExecutionStep>();
        let execution_index = 0;
        while(execution_index < vector::length<vector<u8>>(&option_execution_hashes)) {
          vector::push_back<ExecutionStep>(&mut execution_steps,ExecutionStep {
            execution_hash: *vector::borrow<vector<u8>>(&option_execution_hashes, execution_index),
            execution_parameters:  *vector::borrow<vector<vector<u8>>>(&option_execution_parameters, execution_index),
            execution_parameter_types: *vector::borrow<vector<String>>(&option_execution_parameter_types, execution_index),
            executed: false
          });
          execution_index = execution_index + 1;
        };
        table_with_length::add<String, VoteOption>(&mut vote_options, option, VoteOption {
          vote_weight: 0,
          execution_steps: execution_steps,
          option_elected: false
        });
        vote_options_index = vote_options_index + 1;
      };

      let new_proposal = Proposal<ProposalMetadata> {
        name,
        description,
        creator,
        state: STATE_VOTING,
        max_vote_weight,
        max_voting_time,
        vote_threshold: VoteThreshold {
          approval_quorum,
          quorum
        },
        vote_options: vote_options,
        proposal_content: proposal_content,
        max_voter_options,
        created_at: timestamp::now_seconds(),
        voting_finalized_at:option::none<u64>(),
        executed_at: option::none<u64>(),
        cancelled_at: option::none<u64>(),
        early_tipping
      };

      table_with_length::add<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposals_count + 1, new_proposal);
  }

  public fun vote_for_proposal<ProposalMetadata: store+drop+copy>(voter: &signer, authority_account: address, proposal_id: u64, vote_weight: u64, vote_options: vector<String>) acquires Proposals, VotingRecords, ProposalEvents {
    //CHECKS
    //if proposal exists
    let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    assert!(table_with_length::contains<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id), EPROPOSAL_DOESNT_EXIST);

    //if proposal is in status voting
    let proposal = table_with_length::borrow_mut<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposal_id);
    assert!(proposal.state == STATE_VOTING, EWRONG_PROPOSAL_STATE);
    assert!(proposal.max_voting_time >= timestamp::now_seconds(), EVOTING_TIME_PASSED);

    //If voter doesnt have vote record
      let voting_records = borrow_global_mut<VotingRecords>(authority_account);
      let vote_key = VoteKey {
        proposal_id: proposal_id,
        member_address: signer::address_of(voter),
      };
      assert!(!table_with_length::contains(&voting_records.votes, vote_key), EALREADY_VOTED);
      voting_records.accumulated_votes_weight = voting_records.accumulated_votes_weight + vote_weight;
      table_with_length::add<VoteKey, Vote>(&mut voting_records.votes, vote_key, Vote {
        options: vote_options,
        vote_weight
      });

    //If number of options is higher then max voter options
    assert!(vector::length<String>(&vote_options) <= proposal.max_voter_options, EWRONG_OPTIONS_LEN);

    let quorum_reached = (voting_records.accumulated_votes_weight * 100) / proposal.max_vote_weight;
    let approval_reached = false;
    //if vote_option exists in vote options
    let options_elected=vector::empty();
    let option_index = 0;
    while (option_index < vector::length<String>(&vote_options)) {
      let option_name = *vector::borrow<String>(&vote_options, option_index);
      assert!(table_with_length::contains<String, VoteOption>(&proposal.vote_options, option_name), EWRONG_OPTION);
      let vote_option = table_with_length::borrow_mut<String, VoteOption>(&mut proposal.vote_options, option_name);
      vote_option.vote_weight = vote_option.vote_weight + vote_weight;
      let vote_percentages = (100 * vote_option.vote_weight) / proposal.max_vote_weight;
      if(vote_percentages>proposal.vote_threshold.approval_quorum) {
        vote_option.option_elected = true;
        vector::push_back(&mut options_elected,true);
        approval_reached = true;
      }else{
        vector::push_back(&mut options_elected,false);
      };
      option_index = option_index + 1;
    };
    //Check if voting should be completed
    //If approval quorum is reached
    if(approval_reached) {
    //If early tipping is true 
      if (proposal.early_tipping) {
        //if quorum is reached
        if(quorum_reached >= proposal.vote_threshold.quorum) {
            proposal.voting_finalized_at = option::some<u64>(timestamp::now_seconds());
            proposal.state = STATE_SUCCEEDED;
          }
      }
    };

    let proposal_events=borrow_global_mut<ProposalEvents<ProposalMetadata>>(authority_account);

    event::emit_event<VoteEvent<ProposalMetadata>>(&mut proposal_events.vote_event,VoteEvent{
      proposal_state:proposal.state,
      voting_finalized_at:proposal.voting_finalized_at,
      proposal_id,
      proposal_content:proposal.proposal_content,
      vote_options:vote_options,
      options_elected,
      member_address:signer::address_of(voter),
      vote_weight
    });
  }

  public fun cancel_proposal<ProposalMetadata: store+drop+copy>(authority_account: address, proposal_id: u64) acquires Proposals,ProposalEvents{
    //CHECKS
    //If proposal exists
    let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow_mut<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposal_id);
    //If proposal is in voting state
    assert!(proposal.state == STATE_VOTING, EWRONG_PROPOSAL_STATE);
    //TODO
    proposal.state = STATE_CANCELLED;
    //set cancelled_at
    proposal.cancelled_at = option::some<u64>(timestamp::now_seconds());
    //set state to cancelled

    let events=borrow_global_mut<ProposalEvents<ProposalMetadata>>(authority_account);

    event::emit_event<CancelProposalEvent<ProposalMetadata>>(&mut events.cancel_event,CancelProposalEvent{
      proposal_state:proposal.state,
      proposal_id,
      proposal_content:proposal.proposal_content,
      cancelled_at:option::extract(&mut proposal.cancelled_at)
    })

  }

  public fun finalize_votes<ProposalMetadata: store+copy+drop>(authority_account: address, proposal_id: u64) acquires Proposals, VotingRecords,ProposalEvents {
    //CHECKS
    //if proposal exists
    let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow_mut<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposal_id);
    //If proposal is in voting state
    assert!(proposal.state == STATE_VOTING, EWRONG_PROPOSAL_STATE);
    //if quorum is reached
    let voting_records = borrow_global<VotingRecords>(authority_account);
    let quorum_reached = (voting_records.accumulated_votes_weight * 100) / proposal.max_vote_weight;

    //if voting time passed
    assert!(proposal.max_voting_time <= timestamp::now_seconds(), EVOTING_IN_PROGRESS);

    //set vote finalized at
    proposal.voting_finalized_at = option::some<u64>(timestamp::now_seconds());
    //set state to succedded or defeated based on quorum reached
    if(quorum_reached >= proposal.vote_threshold.quorum) {
      proposal.state = STATE_SUCCEEDED;
    } else {
      proposal.state = STATE_DEFEATED;
    };

    let proposal_events=borrow_global_mut<ProposalEvents<ProposalMetadata>>(authority_account);

    event::emit_event<FinalizeVoteEvent<ProposalMetadata>>(&mut proposal_events.finalize_vote,FinalizeVoteEvent{
      proposal_id,
      proposal_content:proposal.proposal_content,
      proposal_state:proposal.state,
      voting_finalized_at:option::extract(&mut proposal.voting_finalized_at),
    });

  }

  public fun relinquish_vote<ProposalMetadata: store+drop+copy>(voter: &signer, authority_account: address, proposal_id: u64) acquires Proposals, VotingRecords,ProposalEvents {
    let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow_mut<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposal_id);
    assert!(proposal.state == STATE_VOTING, EWRONG_PROPOSAL_STATE);
    assert!(proposal.max_voting_time >= timestamp::now_seconds(), EVOTING_TIME_PASSED);
    let voting_records = borrow_global_mut<VotingRecords>(authority_account);
    let vote_key = VoteKey {
      proposal_id,
      member_address: signer::address_of(voter)
    };
    assert!(table_with_length::contains<VoteKey, Vote>(&voting_records.votes, vote_key), EVOTE_DOESNT_EXIST);
    let vote = table_with_length::borrow_mut<VoteKey, Vote>(&mut voting_records.votes, vote_key);

    let vote_options=vector::empty();
    let options_elected=vector::empty();

    let index = 0;
    while(index < vector::length<String>(&vote.options)) {
      let option_name = *vector::borrow<String>(&vote.options, index);
      vector::push_back(&mut vote_options,option_name);
      
      let proposal_option = table_with_length::borrow_mut<String, VoteOption>(&mut proposal.vote_options, option_name);
      proposal_option.vote_weight = proposal_option.vote_weight - vote.vote_weight;
      if(proposal_option.option_elected) {
      let vote_percentages = (100 * proposal_option.vote_weight) / proposal.max_vote_weight;
         if(vote_percentages < proposal.vote_threshold.approval_quorum) {
            proposal_option.option_elected = false;
         };
            vector::push_back(&mut options_elected, proposal_option.option_elected);

      };
      index = index + 1;
    };


    let events=borrow_global_mut<ProposalEvents<ProposalMetadata>>(authority_account);

    event::emit_event<RelinquishVoteEvent<ProposalMetadata>>(&mut events.relinquish_vote,RelinquishVoteEvent{
      member_address:signer::address_of(voter),
      proposal_id,
      options_elected,
      vote_options,
      proposal_content:proposal.proposal_content,
      vote_weight:vote.vote_weight

    });

    table_with_length::remove<VoteKey, Vote>(&mut voting_records.votes, vote_key);


    
  }

  public fun execute_proposal_option<ProposalMetadata: store+drop+copy>(_payer: &signer, authority_account: address, proposal_id: u64, option: String,
    execution_paramters:vector<vector<u8>>) acquires Proposals,ProposalEvents {

    let proposals=borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    let proposal=table_with_length::borrow_mut<u64,Proposal<ProposalMetadata>>(&mut proposals.proposals,proposal_id);

    assert!(proposal.state==STATE_SUCCEEDED || proposal.state == STATE_EXECUTING,EWRONG_PROPOSAL_STATE);
    proposal.state = STATE_EXECUTING;

    let proposal_option=table_with_length::borrow_mut<String,VoteOption>(&mut proposal.vote_options,option);

    assert!(proposal_option.option_elected,EOPTION_NOT_ELECTED);

    let execution_steps_count=vector::length<ExecutionStep>(&proposal_option.execution_steps);
 
    assert!(execution_steps_count>0,ENON_EXECUTABLE_PROPOSAL);

    let index=0;

    while(index < execution_steps_count){
      let execution_step=vector::borrow_mut<ExecutionStep>(&mut proposal_option.execution_steps,index);
      if(!execution_step.executed){
      let script_hash=transaction_context::get_script_hash();

      assert!(script_hash==execution_step.execution_hash,EINVALID_HASH);


      assert!(execution_step.execution_parameters==execution_paramters,EINVALID_SCRIPT_PARAMS);
      assert!(script_hash==execution_step.execution_hash,EINVALID_HASH);

      execution_step.executed=true;
      if(index + 1 == execution_steps_count) {
        proposal.state = STATE_COMPLETED;
      };
      break
      };
      index=index+1;
    };

    let events=borrow_global_mut<ProposalEvents<ProposalMetadata>>(authority_account);

    event::emit_event<ExecuteProposalOptionEvent<ProposalMetadata>>(&mut events.execute_option,ExecuteProposalOptionEvent{
      proposal_id,
      proposal_state:proposal.state,
      proposal_content:proposal.proposal_content,
      option
    })

  }



  public fun get_proposal_info<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64): (String, String, u8, address, ProposalMetadata, u64, u64, u64, u64, u64, u64, Option<u64>, Option<u64>, Option<u64>,bool) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    (
      proposal.name,
      proposal.description,
      proposal.state,
      proposal.creator,
      proposal.proposal_content,
      proposal.max_vote_weight,
      proposal.max_voting_time,
      proposal.vote_threshold.approval_quorum,
      proposal.vote_threshold.quorum,
      proposal.max_voter_options,
      proposal.created_at,
      proposal.voting_finalized_at,
      proposal.executed_at,
      proposal.cancelled_at,
      proposal.early_tipping
    )
  }

  public fun get_proposal_metadata<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64): (ProposalMetadata) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    (
      proposal.proposal_content,
    )
  }

    public fun get_proposal_rules<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64): (u64, u64, bool, u64) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    (
      proposal.vote_threshold.approval_quorum,
      proposal.vote_threshold.quorum,
      proposal.early_tipping,
      proposal.max_voting_time
    )
  }


  public fun get_proposal_creation_time<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64): (u64) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    (
      proposal.created_at,
    )
  }

  public fun get_proposal_state<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64): (u8) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    (
      proposal.state
    )
  }

  public fun is_option_elected<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64, option: String): (bool) acquires Proposals {
    let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow<u64, Proposal<ProposalMetadata>>(&proposals.proposals, proposal_id);
    let option_info = table_with_length::borrow<String, VoteOption>(&proposal.vote_options, option);
    (
      option_info.option_elected
    )
  }

  public fun get_user_vote_info<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64, user_addr: address): (vector<String>, u64) acquires  VotingRecords {
    assert!(exists<Proposals<ProposalMetadata>>(authority_account), EPROPOSAL_DOESNT_EXIST);
    let voting_records = borrow_global<VotingRecords>(authority_account);
    let vote_key = VoteKey {
      proposal_id,
      member_address: user_addr
    };
    assert!(table_with_length::contains<VoteKey, Vote>(&voting_records.votes, vote_key), EVOTE_DOESNT_EXIST);
    let vote = table_with_length::borrow<VoteKey, Vote>(&voting_records.votes, vote_key);
    (
      vote.options,
      vote.vote_weight
    )

  
  }

  public fun does_user_vote_on_proposal<ProposalMetadata: store + copy>(authority_account: address, proposal_id: u64, user_addr: address): (bool) acquires VotingRecords {
    assert!(exists<Proposals<ProposalMetadata>>(authority_account), EPROPOSAL_DOESNT_EXIST);
    let voting_records = borrow_global<VotingRecords>(authority_account);
      let vote_key = VoteKey {
      proposal_id,
      member_address: user_addr
    };
    (
      table_with_length::contains<VoteKey, Vote>(&voting_records.votes, vote_key)
    )

  }

  public fun update_proposal_metadata<ProposalMetadata: store + copy + drop>(authority_account: address, proposal_id: u64, proposal_metadata: ProposalMetadata) acquires Proposals {
    let proposals = borrow_global_mut<Proposals<ProposalMetadata>>(authority_account);
    let proposal = table_with_length::borrow_mut<u64, Proposal<ProposalMetadata>>(&mut proposals.proposals, proposal_id);
    proposal.proposal_content = proposal_metadata;
  }

  #[view]
  public  fun get_proposal_execution_params<ProposalMetadata:copy+drop+store>(authority_account:address,proposal_id:u64,option:String):VoteOption acquires Proposals{

    let proposals=borrow_global<Proposals<ProposalMetadata>>(authority_account);

    let proposal=table_with_length::borrow<u64,Proposal<ProposalMetadata>>(&proposals.proposals,proposal_id);

    let vote_option=table_with_length::borrow<String,VoteOption>(&proposal.vote_options,option);

    // let execution_step=vector::borrow(&vote_option.execution_steps,0);

    *vote_option
  }

  public fun get_proposal_count<ProposalMetadata: store + copy>(authority_account: address): u64 acquires Proposals {
     let proposals = borrow_global<Proposals<ProposalMetadata>>(authority_account);
     (
      table_with_length::length<u64, Proposal<ProposalMetadata>>(&proposals.proposals)
     )
  }

  public fun check_if_resource_is_registered<ProposalMetadata:store>(authority_account:address):bool{
    exists<Proposals<ProposalMetadata>>(authority_account)
  }


  #[test_only]
  struct TestProposalMetadata has store, drop, copy {
    discussion_link: String
  }

  #[test_only]
  public fun create_basic_proposal(authority_address: address, creator_address: address, early_tipping: bool, 
  max_voting_time_sec: u64, proposal_id: u64, quorum: u64, approval_quorum: u64, max_voter_weight: u64, max_voter_options: u64) acquires Proposals {
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


    let max_voting_time = timestamp::now_seconds() + max_voting_time_sec;

    create_proposal<TestProposalMetadata>(
      creator_address,
      authority_address,
      string::utf8(b"Proposal 1"),
      string::utf8(b"Proposal description"),
      TestProposalMetadata {
        discussion_link: string::utf8(b"Proposal discussion"),
      },
      max_voter_weight,
      max_voting_time,
      approval_quorum,
      quorum,
      options,
      option_execution_parameters,
      option_execution_hashes,
      option_execution_parameter_types,
      max_voter_options,
      early_tipping
    );

    let proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    assert!(table_with_length::contains<u64, Proposal<TestProposalMetadata>>(&proposals.proposals, proposal_id), 0);
    let created_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&proposals.proposals, proposal_id);
    assert!(created_proposal.name == string::utf8(b"Proposal 1"), 0);
    assert!(created_proposal.description == string::utf8(b"Proposal description"), 0);
    assert!(created_proposal.proposal_content.discussion_link == string::utf8(b"Proposal discussion"), 0);
    assert!(created_proposal.max_vote_weight == max_voter_weight, 0);
    assert!(created_proposal.max_voting_time == max_voting_time, 0);
    assert!(created_proposal.vote_threshold.quorum == quorum, 0);
    assert!(created_proposal.vote_threshold.approval_quorum == approval_quorum, 0);
    assert!(table_with_length::length<String, VoteOption>(&created_proposal.vote_options) == 2, 0);

    let first_option = table_with_length::borrow<String, VoteOption>(&created_proposal.vote_options,  string::utf8(b"Option1"));
    assert!(first_option.vote_weight == 0, 0);
    assert!(first_option.option_elected == false, 0);
    assert!(vector::length<ExecutionStep>(&first_option.execution_steps) == 0, 0); 

    let second_option = table_with_length::borrow<String, VoteOption>(&created_proposal.vote_options,  string::utf8(b"Option2"));
    assert!(second_option.vote_weight == 0, 0);
    assert!(second_option.option_elected == false, 0);
    assert!(vector::length<ExecutionStep>(&second_option.execution_steps) == 0, 0);

  }


  #[test(framework = @0x1, authority = @0x222, creator = @0x123, user = @0x543)]
  public fun test_basic_proposals_flow(framework: signer, authority: signer, creator: signer, user: signer) acquires Proposals, VotingRecords,ProposalEvents {
    //Prepare accounts for test
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 60, 1, 50,60,10,2);
    create_basic_proposal(authority_address, creator_address, true, 60, 2,50,60,10,2);

    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 2, options);

    let voting_records = borrow_global<VotingRecords>(authority_address);
    let vote_key = VoteKey {
        proposal_id: 1,
        member_address: creator_address
    };
    assert!(table_with_length::contains(&voting_records.votes, vote_key), 0);
    let vote_record = table_with_length::borrow(&voting_records.votes, vote_key);
    assert!(vote_record.vote_weight == 2, 0);
    assert!(vote_record.options == options, 0);
    assert!(voting_records.accumulated_votes_weight == 2, 0);
    assert!(table_with_length::length(&voting_records.votes) ==1, 0);

    let proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&proposals.proposals, 1);
    let vote_option = table_with_length::borrow<String, VoteOption>(&proposal.vote_options,  string::utf8(b"Option1"));
    assert!(vote_option.vote_weight == 2, 0);
    assert!(vote_option.option_elected == false, 0);
    assert!(proposal.state == STATE_VOTING, 0);


    //User 2 vote for proposal
    vector::remove<String>(&mut options, 1);
    vote_for_proposal<TestProposalMetadata>(&user,authority_address, 1, 5, options);
    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    let updated_vote_option = table_with_length::borrow<String, VoteOption>(&updated_proposal.vote_options,  string::utf8(b"Option1"));
    let updated_vote_option_two = table_with_length::borrow<String, VoteOption>(&updated_proposal.vote_options,  string::utf8(b"Option2"));
    assert!(updated_vote_option_two.vote_weight == 2, 0);
    assert!(updated_vote_option_two.option_elected == false, 0);
    assert!(updated_vote_option.vote_weight == 7, 0);
    assert!(updated_vote_option.option_elected == true, 0);
    assert!(updated_proposal.state == STATE_SUCCEEDED, 0);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  public fun test_cancel_proposal(framework: signer, authority: signer, creator: signer) acquires Proposals,ProposalEvents {
     let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 60, 1, 50,60,10,2);
    cancel_proposal<TestProposalMetadata>(authority_address, 1);

    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    assert!(updated_proposal.state == STATE_CANCELLED, 0);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  public fun test_finalize_votes_defeated(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
     let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 0, 1, 50,60,10,2);
    finalize_votes<TestProposalMetadata>(authority_address, 1);

    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    assert!(updated_proposal.state == STATE_DEFEATED, 0);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  public fun test_finalize_votes_succeeded(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
     let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 0, 1, 50,100,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 6, options);

    finalize_votes<TestProposalMetadata>(authority_address, 1);

    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    assert!(updated_proposal.state == STATE_SUCCEEDED, 0);
    let updated_vote_option = table_with_length::borrow<String, VoteOption>(&updated_proposal.vote_options,  string::utf8(b"Option1"));
    let updated_vote_option_two = table_with_length::borrow<String, VoteOption>(&updated_proposal.vote_options,  string::utf8(b"Option2"));
    assert!(updated_vote_option_two.vote_weight == 6, 0);
    assert!(updated_vote_option_two.option_elected == false, 0);
    assert!(updated_vote_option.vote_weight == 6, 0);
    assert!(updated_vote_option.option_elected == false, 0);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  public fun test_non_early_proposals_flow(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
    //Prepare accounts for test
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));
    vector::push_back<String>(&mut options, string::utf8(b"Option2"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, false, 0, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 10, options);
    let proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&proposals.proposals, 1);
    let vote_option = table_with_length::borrow<String, VoteOption>(&proposal.vote_options,  string::utf8(b"Option1"));
    assert!(vote_option.vote_weight == 10, 0);
    assert!(vote_option.option_elected == true, 0);
    assert!(proposal.state == STATE_VOTING, 0);

    finalize_votes<TestProposalMetadata>(authority_address, 1);
    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    assert!(updated_proposal.state == STATE_SUCCEEDED, 0);

  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  public fun test_relinquish_vote(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, false, 10, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 10, options);
    let proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&proposals.proposals, 1);
    let vote_option = table_with_length::borrow<String, VoteOption>(&proposal.vote_options,  string::utf8(b"Option1"));
    assert!(vote_option.vote_weight == 10, 0);
    assert!(vote_option.option_elected == true, 0);
    assert!(proposal.state == STATE_VOTING, 0);

    relinquish_vote<TestProposalMetadata>(&creator, authority_address, 1);
    let updated_proposals = borrow_global<Proposals<TestProposalMetadata>>(authority_address);
    let updated_proposal = table_with_length::borrow<u64, Proposal<TestProposalMetadata>>(&updated_proposals.proposals, 1);
    let updated_vote_option = table_with_length::borrow<String, VoteOption>(&updated_proposal.vote_options,  string::utf8(b"Option1"));
    assert!(updated_vote_option.vote_weight == 0, 0);
    assert!(updated_vote_option.option_elected == false, 0);
    assert!(updated_proposal.state == STATE_VOTING, 0); 

  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  #[expected_failure(abort_code = EWRONG_PROPOSAL_STATE)]
  public fun test_relinquish_vote_in_after_voting(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 10, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 10, options);
    relinquish_vote<TestProposalMetadata>(&creator, authority_address, 1);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  #[expected_failure(abort_code = EWRONG_PROPOSAL_STATE)]
  public fun test_relinquish_vote_after_cancel(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 10, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 2, options);
    cancel_proposal<TestProposalMetadata>(authority_address, 1);
    relinquish_vote<TestProposalMetadata>(&creator, authority_address, 1);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  #[expected_failure(abort_code = EWRONG_PROPOSAL_STATE)]
  public fun test_relinquish_vote_after_finalize(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents {
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 0, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 2, options);
    finalize_votes<TestProposalMetadata>(authority_address, 1);
    relinquish_vote<TestProposalMetadata>(&creator, authority_address, 1);
  }

  #[test(framework = @0x1, authority = @0x222, creator = @0x123)]
  #[expected_failure(abort_code = EALREADY_VOTED)]
  public fun test_double_vote_with_same_address(framework: signer, authority: signer, creator: signer) acquires Proposals, VotingRecords,ProposalEvents{
    let creator_address = signer::address_of(&creator);
    account::create_account_for_test(creator_address);
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);

    initialize<TestProposalMetadata>(&authority);

    let options: vector<String> = vector::empty<String>();
    vector::push_back<String>(&mut options, string::utf8(b"Option1"));

    timestamp::set_time_has_started_for_testing(&framework);
    create_basic_proposal(authority_address, creator_address, true, 0, 1, 50,60,10,2);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 2, options);
    vote_for_proposal<TestProposalMetadata>(&creator,authority_address, 1, 2, options);

  }



}